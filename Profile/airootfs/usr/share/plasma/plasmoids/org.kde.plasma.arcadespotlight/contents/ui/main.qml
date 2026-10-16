import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.kicker as Kicker
import Qt.labs.folderlistmodel 2.15
import Qt.labs.settings 1.0

PlasmoidItem {
    id: root

    Settings {
        id: layoutSettings
        category: "ArcadeSpotlight"
        property bool isGridView: false
    }


    // AI state
    property string aiQuery: ""
    property string aiAnswer: ""
    property var    aiHistory: []
    property bool   aiLoading: false
    property string aiError: ""
    property var    answerSegments: []

    // ── Parse answer into [{type:"text"|"code", lang, content}] ──
    function parseSegments(text) {
        var segments = [];
        var regex = /```([a-zA-Z0-9+#\-\.]*)\r?\n([\s\S]*?)```/g;
        var lastIndex = 0;
        var match;
        while ((match = regex.exec(text)) !== null) {
            if (match.index > lastIndex) {
                var textPart = text.substring(lastIndex, match.index);
                if (textPart.trim() !== "") {
                    segments.push({ type: "text", content: textPart });
                }
            }
            segments.push({ type: "code", lang: match[1] || "code", content: match[2].trim() });
            lastIndex = regex.lastIndex;
        }
        if (lastIndex < text.length) {
            var tail = text.substring(lastIndex);
            if (tail.trim() !== "") {
                segments.push({ type: "text", content: tail });
            }
        }
        return segments;
    }

    onAiAnswerChanged: {
        var rawText = aiAnswer;
        
        var accessMatch = rawText.match(/<MEMORY_ACCESSED>/g);
        if (accessMatch) {
            aiStatus = "Memory Accessed";
            rawText = rawText.replace(/<MEMORY_ACCESSED>/g, "").trim();
        }
        
        var appendMatch = rawText.match(/<APPEND_MEMORY>([\s\S]*?)<\/APPEND_MEMORY>/);
        if (appendMatch) {
            var currentMem = plasmoid.configuration.aiMemory || "";
            currentMem = currentMem.trim();
            var newFact = appendMatch[1].trim();
            plasmoid.configuration.aiMemory = currentMem ? (currentMem + "\n" + newFact) : newFact;
            rawText = rawText.replace(/<APPEND_MEMORY>[\s\S]*?<\/APPEND_MEMORY>/g, "").trim();
            aiStatus = "Memory Updated";
        }
        
        var memMatch = rawText.match(/<UPDATE_MEMORY>([\s\S]*?)<\/UPDATE_MEMORY>/);
        if (memMatch) {
            plasmoid.configuration.aiMemory = memMatch[1].trim();
            rawText = rawText.replace(/<UPDATE_MEMORY>[\s\S]*?<\/UPDATE_MEMORY>/g, "").trim();
            aiStatus = "Memory Updated";
        }
        
        answerSegments = (rawText !== "") ? parseSegments(rawText) : [];
    }

    function isAiQuery(text) {
        var t = text.trim().toLowerCase();
        return t === "/ai" || t.startsWith("/ai ");
    }

    function getAiQuery(text) {
        var t = text.trim();
        if (t.toLowerCase() === "/ai") return "";
        return t.substring(4).trim();
    }
    property string   aiStatus: ""

    function fetchAiAnswer(query, isFollowup) {
        aiHistory = [{role: "user", content: query}];
        aiAnswer = "";
        aiError = "";
        aiStatus = "";
        aiLoading = true;
        aiQuery = query;

        var provider = plasmoid.configuration.aiProvider;
        var apiKey   = plasmoid.configuration.aiApiKey;
        var baseSysPrompt = "You are a helpful assistant integrated into ArcadeLinux Spotlight. Be concise and use markdown formatting where helpful. You have access to a User Memory file. " +
            "CRITICAL RULES:\n" +
            "1. NEVER append or update memory unless the user EXPLICITLY asks you to remember, save, or update a fact.\n" +
            "2. To append a new fact: <APPEND_MEMORY>new fact</APPEND_MEMORY>\n" +
            "3. To replace the ENTIRE memory: <UPDATE_MEMORY>new content</UPDATE_MEMORY>\n" +
            "4. If you USE or reference any fact from the memory to answer the user's query, you MUST output EXACTLY <MEMORY_ACCESSED> at the end of your response to trigger the UI indicator.";
        
        var sysPrompt = baseSysPrompt;
        var memory = plasmoid.configuration.aiMemory || "";
        if (memory) {
            sysPrompt += "\n\nUser Memory:\n" + memory + "\n\nCRITICAL INSTRUCTION: Only mention or base your response on the above facts if explicitly asked or relevant to the query. ALWAYS follow any styling or formatting preferences provided in the memory.";
        }

        if (!apiKey) {
            aiError = "No API key set. Right-click the Spotlight icon → Configure to add one.";
            aiLoading = false;
            return;
        }

        var xhr = new XMLHttpRequest();
        var url, body, headers = {};

        if (provider === "gemini") {
            url = "https://generativelanguage.googleapis.com/v1beta/models/" + plasmoid.configuration.aiGeminiModel + ":generateContent?key=" + apiKey;
            headers["Content-Type"] = "application/json";
            body = JSON.stringify({
                system_instruction: { parts: [{ text: sysPrompt }] },
                contents: aiHistory.map(function(m) { return { role: m.role === "assistant" ? "model" : "user", parts: [{ text: m.content }] }; })
            });
        } else if (provider === "openrouter") {
            url = "https://openrouter.ai/api/v1/chat/completions";
            headers["Content-Type"] = "application/json";
            headers["Authorization"] = "Bearer " + apiKey;
            body = JSON.stringify({
                model: plasmoid.configuration.aiOpenrouterModel,
                messages: [{ role: "system", content: sysPrompt }].concat(aiHistory)
            });
        } else if (provider === "groq") {
            url = "https://api.groq.com/openai/v1/chat/completions";
            headers["Content-Type"] = "application/json";
            headers["Authorization"] = "Bearer " + apiKey;
            body = JSON.stringify({
                model: plasmoid.configuration.aiGroqModel,
                messages: [{ role: "system", content: sysPrompt }].concat(aiHistory)
            });
        } else {
            url = "https://api.openai.com/v1/chat/completions";
            headers["Content-Type"] = "application/json";
            headers["Authorization"] = "Bearer " + apiKey;
            body = JSON.stringify({
                model: plasmoid.configuration.aiOpenaiModel,
                messages: [{ role: "system", content: sysPrompt }].concat(aiHistory)
            });
        }

        xhr.open("POST", url);
        for (var h in headers) xhr.setRequestHeader(h, headers[h]);

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4) return;
            try {
                var resp = JSON.parse(xhr.responseText);
                var rawAns = "";
                if (provider === "gemini") {
                    rawAns = resp.candidates[0].content.parts[0].text;
                } else {
                    rawAns = resp.choices[0].message.content;
                }
                
                aiLoading = false;
                
                aiAnswer = rawAns;
            } catch(e) {
                aiLoading = false;
                aiError = "Error: " + (xhr.status === 401 ? "Invalid API key." : (xhr.status === 429 ? "Rate limited. Try again." : xhr.responseText.substring(0, 120)));
            }
        };

        xhr.send(body);
    }


    property string currentHoveredUrl: ""

    // Hidden clipboard helper
    TextEdit {
        id: clipHelper
        visible: false
    }

    preferredRepresentation: compactRepresentation
    fullRepresentation: Item {}

    Plasmoid.onActivated: {
        spotlightDialog.visible = !spotlightDialog.visible
    }

    Kirigami.Action {
        shortcut: "Alt+Space"
        onTriggered: spotlightDialog.visible = !spotlightDialog.visible
    }

    compactRepresentation: Item {
        implicitWidth: 32
        implicitHeight: 32

        Kirigami.Icon {
            anchors.centerIn: parent
            width: 22
            height: 22
            source: "search"
            color: mouseArea.containsMouse ? "#ffffff" : "#d8d8dc"
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: spotlightDialog.visible = !spotlightDialog.visible
        }
    }

    Connections {
        target: root
        function onExpandedChanged() {
            if (root.expanded) {
                root.expanded = false
            }
        }
    }

    function resolvePath(query) {
        var trimmed = query.trim();
        var isWildcard = isWildcardQuery(trimmed);
        var lastSlash = trimmed.lastIndexOf("/");

        if (isWildcard && lastSlash !== -1) {
            trimmed = trimmed.substring(0, lastSlash);
            if (trimmed === "") trimmed = "/";
        } else if (isWildcard) {
            trimmed = "~";
        }

        var homePath = StandardPaths.writableLocation(StandardPaths.HomeLocation);

        if (trimmed === "~" || trimmed === "~/") return "file://" + homePath;
        if (trimmed.startsWith("~/")) {
            return "file://" + homePath + "/" + trimmed.substring(2);
        }

        if (trimmed.startsWith("/")) {
            var parts = trimmed.substring(1).split("/");
            var topDir = parts[0].toLowerCase();
            var rest = parts.slice(1).join("/");

            var matchedHomeFolder = "";
            if (topDir === "desktop") matchedHomeFolder = homePath + "/Desktop";
            else if (topDir === "downloads") matchedHomeFolder = homePath + "/Downloads";
            else if (topDir === "documents") matchedHomeFolder = homePath + "/Documents";
            else if (topDir === "pictures") matchedHomeFolder = homePath + "/Pictures";
            else if (topDir === "music") matchedHomeFolder = homePath + "/Music";
            else if (topDir === "videos") matchedHomeFolder = homePath + "/Videos";

            if (matchedHomeFolder !== "") {
                return "file://" + matchedHomeFolder + (rest !== "" ? "/" + rest : "");
            }
        }
        return "";
    }

    function isFolderPath(query) {
        var trimmed = query.trim();
        if (trimmed === "") return false;

        var isWildcard = isWildcardQuery(trimmed);
        if (isWildcard && trimmed.indexOf("/") === -1) {
            return true;
        }

        var lastSlash = trimmed.lastIndexOf("/");
        var checkStr = trimmed;
        if (isWildcard && lastSlash !== -1) {
            checkStr = trimmed.substring(0, lastSlash);
            if (checkStr === "") checkStr = "/";
        }

        return (checkStr.startsWith("/Desktop") || checkStr.startsWith("/Downloads") || checkStr.startsWith("/Documents") || checkStr.startsWith("/Pictures") || checkStr.startsWith("/Music") || checkStr.startsWith("/Videos") || checkStr.startsWith("~"));
    }

    function isWildcardQuery(query) {
        var trimmed = query.trim();
        return trimmed.includes("*") || trimmed.includes("?");
    }

    function getWildcardFilter(query) {
        var trimmed = query.trim();
        if (!isWildcardQuery(trimmed)) return [];
        var lastSlash = trimmed.lastIndexOf("/");
        if (lastSlash !== -1) {
            return [trimmed.substring(lastSlash + 1)];
        }
        return [trimmed];
    }

    Kicker.RunnerModel {
        id: runnerModel
        appletInterface: plasmoid
        query: searchField.text
        mergeResults: true
        runners: [
            "services", "baloosearch", "webshortcuts", "calculator",
            "krunner_recentdocuments", "locations", "places",
            "systemsettings", "dictionary", "appstream", "bookmarks",
            "sessions", "powerdevil", "kill", "datetime", "spellcheck", "krunner_webshortcuts", "krunner_services"
        ]
    }

    FolderListModel {
        id: folderModel
        folder: resolvePath(searchField.text)
        showDirs: true
        showFiles: true
        showHidden: false
        nameFilters: getWildcardFilter(searchField.text)
    }

    PlasmaCore.Dialog {
        id: spotlightDialog
        objectName: "arcadeSpotlightPopup"
        flags: Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint
        location: PlasmaCore.Types.Floating
        hideOnWindowDeactivate: true
        backgroundHints: PlasmaCore.Dialog.NoBackground

        x: {
            var screen = Qt.application.screens[0];
            return screen ? Math.round((screen.width - mainItem.width) / 2) : 0;
        }
        y: {
            var screen = Qt.application.screens[0];
            return screen ? Math.round((screen.height - 54) / 2) - 140 : 0;
        }

        onVisibleChanged: {
            if (visible) {
                searchField.text = ""
                previewOverlay.visible = false
                searchField.forceActiveFocus()
                openAnim.restart()
            }
        }

        mainItem: Item {
            id: containerItem
            width: searchContainer.width + 80
            height: searchContainer.height + 80

            scale: 0.94
            opacity: 0
            transformOrigin: Item.Top

            SequentialAnimation {
                id: openAnim
                ParallelAnimation {
                    NumberAnimation { target: containerItem; property: "opacity"; to: 1; duration: 140; easing.type: Easing.OutQuad }
                    NumberAnimation { target: containerItem; property: "scale"; to: 1.0; duration: 220; easing.type: Easing.OutCubic }
                }
            }

            SequentialAnimation {
                id: closeAnim
                ParallelAnimation {
                    NumberAnimation { target: containerItem; property: "opacity"; to: 0; duration: 120; easing.type: Easing.InQuad }
                    NumberAnimation { target: containerItem; property: "scale"; to: 0.94; duration: 120; easing.type: Easing.InQuad }
                }
                ScriptAction { script: { spotlightDialog.visible = false; } }
            }

            // ── Normal mode: premium gradient ambient glow (hidden in AI mode) ──
            Rectangle {
                anchors.centerIn: searchContainer
                width:  searchContainer.width  + 16
                height: searchContainer.height + 16
                radius: searchContainer.radius  + 8
                color: "transparent"
                visible: !isAiQuery(searchField.text)
                opacity: 0.45
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { id: normGlow0; position: 0.0; color: Qt.rgba(0.5, 0.4, 0.9, 0.18) }
                    GradientStop { id: normGlow1; position: 0.5; color: Qt.rgba(1,   1,   1,   0.10) }
                    GradientStop { id: normGlow2; position: 1.0; color: Qt.rgba(0.2, 0.6, 1.0, 0.18) }
                }

                SequentialAnimation {
                    running: !isAiQuery(searchField.text)
                    loops: Animation.Infinite
                    ParallelAnimation {
                        ColorAnimation { target: normGlow0; property: "color"; to: Qt.rgba(0.2, 0.6, 1.0, 0.18); duration: 3000; easing.type: Easing.InOutSine }
                        ColorAnimation { target: normGlow2; property: "color"; to: Qt.rgba(0.5, 0.4, 0.9, 0.18); duration: 3000; easing.type: Easing.InOutSine }
                    }
                    ParallelAnimation {
                        ColorAnimation { target: normGlow0; property: "color"; to: Qt.rgba(0.5, 0.4, 0.9, 0.18); duration: 3000; easing.type: Easing.InOutSine }
                        ColorAnimation { target: normGlow2; property: "color"; to: Qt.rgba(0.2, 0.6, 1.0, 0.18); duration: 3000; easing.type: Easing.InOutSine }
                    }
                }
            }

            // ── Siri gradient glow — 3 layered halos (simulates soft blur/glow) ──
            Rectangle {
                anchors.centerIn: searchContainer
                width:  searchContainer.width  + 14; height: searchContainer.height + 14
                radius: searchContainer.radius  + 7
                visible: isAiQuery(searchField.text)
                opacity: (aiLoading ? 0.28 : 0.12)
                Behavior on opacity { NumberAnimation { duration: 500 } }
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: glow0.color }
                    GradientStop { position: 0.5; color: glow1.color }
                    GradientStop { position: 1.0; color: glow2.color }
                }
            }
            Rectangle {
                anchors.centerIn: searchContainer
                width:  searchContainer.width  + 7; height: searchContainer.height + 7
                radius: searchContainer.radius  + 3
                visible: isAiQuery(searchField.text)
                opacity: (aiLoading ? 0.50 : 0.22)
                Behavior on opacity { NumberAnimation { duration: 500 } }
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: glow0.color }
                    GradientStop { position: 0.5; color: glow1.color }
                    GradientStop { position: 1.0; color: glow2.color }
                }
            }

            // Inner 1px gradient border (sharp, sits right on the edge)
            Rectangle {
                id: glowBorderRect
                anchors.centerIn: searchContainer
                width:  searchContainer.width  + 2
                height: searchContainer.height + 2
                radius: searchContainer.radius  + 1
                visible: isAiQuery(searchField.text)
                opacity: aiLoading ? 1.0 : 0.6
                Behavior on opacity { NumberAnimation { duration: 500 } }

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { id: glow0; position: 0.0;  color: "#bf5af2" }
                    GradientStop { id: glow1; position: 0.5;  color: "#0a84ff" }
                    GradientStop { id: glow2; position: 1.0;  color: "#30d158" }
                }

                // Cycle gradient colors while loading
                SequentialAnimation {
                    running: aiLoading && isAiQuery(searchField.text)
                    loops: Animation.Infinite
                    ParallelAnimation {
                        ColorAnimation { target: glow0; property: "color"; to: "#0a84ff"; duration: 1200; easing.type: Easing.InOutSine }
                        ColorAnimation { target: glow1; property: "color"; to: "#30d158"; duration: 1200; easing.type: Easing.InOutSine }
                        ColorAnimation { target: glow2; property: "color"; to: "#bf5af2"; duration: 1200; easing.type: Easing.InOutSine }
                    }
                    ParallelAnimation {
                        ColorAnimation { target: glow0; property: "color"; to: "#30d158"; duration: 1200; easing.type: Easing.InOutSine }
                        ColorAnimation { target: glow1; property: "color"; to: "#bf5af2"; duration: 1200; easing.type: Easing.InOutSine }
                        ColorAnimation { target: glow2; property: "color"; to: "#0a84ff"; duration: 1200; easing.type: Easing.InOutSine }
                    }
                    ParallelAnimation {
                        ColorAnimation { target: glow0; property: "color"; to: "#bf5af2"; duration: 1200; easing.type: Easing.InOutSine }
                        ColorAnimation { target: glow1; property: "color"; to: "#0a84ff"; duration: 1200; easing.type: Easing.InOutSine }
                        ColorAnimation { target: glow2; property: "color"; to: "#30d158"; duration: 1200; easing.type: Easing.InOutSine }
                    }
                }
            }

            Kirigami.ShadowedRectangle {
                id: searchContainer
                anchors.centerIn: parent
                width: searchField.text === "" ? 660 : 780
                height: searchField.text === "" ? 56 : (isAiQuery(searchField.text) ? Math.max(aiCard.implicitHeight + 72, 160) : 536)
                radius: 20

                color: Qt.rgba(0.085, 0.085, 0.095, 0.95)
                // Normal white border when not in AI mode; in AI mode the glowBorderRect handles it
                border.color: isAiQuery(searchField.text) ? Qt.rgba(1,1,1,0.0) : Qt.rgba(1, 1, 1, 0.28)
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 300 } }

                shadow.size: 0
                shadow.color: "transparent"

                Behavior on width  { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                // Single clean background — no decorative borders stacking
                // (glow effect is handled by glowBorderRect layers behind)

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 22
                            anchors.rightMargin: 22
                            spacing: 14

                            // Search icon
                            Kirigami.Icon {
                                source: isFolderPath(searchField.text) ? "folder" : "search"
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                Layout.alignment: Qt.AlignVCenter
                                color: Qt.rgba(1, 1, 1, 0.55)
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            TextField {
                                id: searchField
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                font.family: "SF Pro Display, Inter, -apple-system, Segoe UI, sans-serif"
                                font.pixelSize: 19
                                font.weight: Font.Normal
                                font.letterSpacing: 0.1
                                color: "#f5f5f7"
                                placeholderText: isAiQuery(searchField.text) ? "" : "Search or Ask  ·  type /ai to ask AI"
                                placeholderTextColor: Qt.rgba(1, 1, 1, 0.30)
                                background: Item {}
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                selectionColor: Qt.rgba(0.0, 0.48, 1.0, 0.55)

                                onTextChanged: {
                                    if (!isAiQuery(text)) {
                                        aiAnswer = "";
                                        aiError = "";
                                        aiLoading = false;
                                    }
                                }

                                onAccepted: {
                                    if (isAiQuery(text)) {
                                        var q = getAiQuery(text);
                                        if (q.length > 0 && !aiLoading) {
                                            fetchAiAnswer(q);
                                        }
                                        return;
                                    }
                                    
                                    var hasResults = layoutSettings.isGridView ? gridResults.count > 0 : searchResults.count > 0;
                                    if (!hasResults && text.trim().length > 0) {
                                        searchField.text = "/ai " + text.trim();
                                        fetchAiAnswer(text.trim());
                                        return;
                                    }

                                    if (layoutSettings.isGridView) {
                                        gridResults.triggerCurrent();
                                    } else {
                                        searchResults.triggerCurrent();
                                    }
                                 }

                                Keys.onSpacePressed: (event) => {
                                    if (root.currentHoveredUrl !== "") {
                                        var urlStr = root.currentHoveredUrl;
                                        var c = urlStr.toLowerCase();
                                        if (c.endsWith(".png") || c.endsWith(".jpg") || c.endsWith(".jpeg") || c.endsWith(".svg") || c.endsWith(".gif") || c.endsWith(".webp") || c.endsWith(".bmp")) {
                                            previewImage.source = urlStr;
                                            previewOverlay.visible = true;
                                            event.accepted = true;
                                            return;
                                        }
                                    }
                                    if (searchField.activeFocus) {
                                        event.accepted = false;
                                    } else if (isFolderPath(searchField.text) && gridResults.currentIndex >= 0 && gridResults.currentIndex < folderModel.count) {
                                        var fileUrl = folderModel.get(gridResults.currentIndex, "fileUrl");
                                        var isDir = folderModel.get(gridResults.currentIndex, "fileIsDir");
                                        if (!isDir && fileUrl) {
                                            previewImage.source = fileUrl;
                                            previewOverlay.visible = true;
                                            event.accepted = true;
                                        }
                                    }
                                }

                                Keys.onReleased: (event) => {
                                    if (event.key === Qt.Key_Space) {
                                        previewOverlay.visible = false;
                                    }
                                }

                                Keys.onDownPressed: {
                                    if (searchField.text !== "") {
                                        if (layoutSettings.isGridView) {
                                            gridResults.forceActiveFocus();
                                            if (gridResults.currentIndex < 0) gridResults.currentIndex = 0;
                                        } else {
                                            searchResults.forceActiveFocus();
                                            if (searchResults.currentIndex < 0) searchResults.currentIndex = 0;
                                        }
                                    }
                                }

                                Keys.onEscapePressed: {
                                    if (previewOverlay.visible) {
                                        previewOverlay.visible = false;
                                    } else if (searchField.text !== "") {
                                        searchField.text = ""
                                    } else {
                                        closeAnim.restart()
                                    }
                                }
                            }

                            Text {
                                text: searchField.text !== "" && !isFolderPath(searchField.text) && !isAiQuery(searchField.text) ? runnerModel.count + " results" : ""
                                color: Qt.rgba(1, 1, 1, 0.32)
                                font.pixelSize: 11
                                Layout.alignment: Qt.AlignVCenter
                                visible: text !== ""
                            }

                            Rectangle {
                                Layout.preferredWidth: 18
                                Layout.preferredHeight: 18
                                Layout.alignment: Qt.AlignVCenter
                                radius: 9
                                color: clearMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
                                visible: searchField.text !== ""
                                opacity: visible ? 1 : 0

                                Behavior on opacity { NumberAnimation { duration: 120 } }

                                Behavior on color { ColorAnimation { duration: 100 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    font.pixelSize: 9
                                    color: Qt.rgba(1, 1, 1, 0.75)
                                }

                                MouseArea {
                                    id: clearMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        searchField.text = "";
                                        searchField.forceActiveFocus();
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                Layout.alignment: Qt.AlignVCenter
                                radius: 6
                                color: toggleMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                visible: searchField.text !== "" && !isAiQuery(searchField.text)
                                
                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: 14
                                    height: 14
                                    source: layoutSettings.isGridView ? "view-list-details" : "view-grid"
                                    color: Qt.rgba(1, 1, 1, 0.55)
                                }
                                
                                MouseArea {
                                    id: toggleMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        layoutSettings.isGridView = !layoutSettings.isGridView;
                                        searchField.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                        visible: searchField.text !== ""
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                    }

                    // ---- Siri-style AI Card ----
                    Item {
                        id: aiCard
                        Layout.fillWidth: true
                        implicitHeight: siriCardRect.height + 20
                        Layout.preferredHeight: implicitHeight
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        Layout.bottomMargin: 8
                        visible: isAiQuery(searchField.text)
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                        // Clean thin animated border on the card itself (no rotation needed)
                        // The main spotlight border already handles the Siri glow effect

                        Rectangle {
                            id: siriCardRect
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 6
                            radius: 14
                            color: Qt.rgba(0.0, 0.0, 0.0, 0.0)  // transparent
                            border.width: 0
                            height: siriCol.implicitHeight + 20
                            clip: false  // allow Flickable inside to handle clipping

                            Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                            ColumnLayout {
                                id: siriCol
                                anchors {
                                    left: parent.left; right: parent.right; top: parent.top
                                    margins: 16
                                }
                                spacing: 12

                                // ── Top bar: sparkle + label + provider badge ──
                                RowLayout {
                                    spacing: 6
                                    Layout.fillWidth: true

                                    // Animated tri-color Siri orb
                                    Item {
                                        width: 22; height: 22
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 18; height: 18; radius: 9
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0.0; color: "#bf5af2" }
                                                GradientStop { position: 0.5; color: "#0a84ff" }
                                                GradientStop { position: 1.0; color: "#30d158" }
                                            }
                                            SequentialAnimation on scale {
                                                loops: Animation.Infinite
                                                running: aiLoading
                                                NumberAnimation { to: 1.15; duration: 700; easing.type: Easing.InOutSine }
                                                NumberAnimation { to: 0.90; duration: 700; easing.type: Easing.InOutSine }
                                            }
                                            scale: aiLoading ? 1 : 1
                                        }
                                        // Static sparkle when idle
                                        Text {
                                            anchors.centerIn: parent
                                            text: "✦"
                                            font.pixelSize: 13
                                            color: "#0a84ff"
                                            visible: !aiLoading
                                        }
                                    }

                                    Text {
                                        text: aiLoading ? "Thinking…" : (aiAnswer !== "" ? "Answer" : aiError !== "" ? "Error" : "Press Enter to ask")
                                        color: aiLoading ? "#bf5af2" : (aiAnswer !== "" ? "#e8e8ed" : aiError !== "" ? "#ff375f" : Qt.rgba(1,1,1,0.45))
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        font.letterSpacing: 0.3
                                        Behavior on color { ColorAnimation { duration: 300 } }
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Provider badge pill
                                    Rectangle {
                                        height: 18; radius: 9
                                        width: providerLabel.implicitWidth + 14
                                        color: Qt.rgba(1,1,1,0.07)
                                        Text {
                                            id: providerLabel
                                            anchors.centerIn: parent
                                            text: plasmoid.configuration.aiProvider === "gemini" ? "Gemini" :
                                                  plasmoid.configuration.aiProvider === "openrouter" ? "OpenRouter" :
                                                  plasmoid.configuration.aiProvider === "groq" ? "Groq" : "OpenAI"
                                            color: Qt.rgba(1,1,1,0.35)
                                            font.pixelSize: 10
                                            font.weight: Font.Medium
                                        }
                                    }
                                }

                                                                // ── Error text ──
                                Text {
                                    Layout.fillWidth: true
                                    visible: aiError !== ""
                                    text: aiError
                                    color: "#ff375f"
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                }
                                
                                // ── User question bubble (Siri right-side pill) ──
                                Item {
                                    Layout.fillWidth: true
                                    height: questionBubble.height
                                    visible: aiQuery !== "" && (aiLoading || aiAnswer !== "" || aiError !== "")
                                    opacity: visible ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }

                                    Rectangle {
                                        id: questionBubble
                                        anchors.right: parent.right
                                        width: Math.min(questionText.implicitWidth + 24, parent.width * 0.85)
                                        height: questionText.implicitHeight + 16
                                        radius: 14
                                        color: Qt.rgba(0.18, 0.18, 0.22, 1.0)

                                        Text {
                                            id: questionText
                                            anchors {
                                                left: parent.left; right: parent.right
                                                top: parent.top; bottom: parent.bottom
                                                margins: 12
                                            }
                                            text: aiQuery
                                            color: "#e8e8ed"
                                            font.pixelSize: 13
                                            font.family: "SF Pro Text, Inter, -apple-system, sans-serif"
                                            wrapMode: Text.WordWrap
                                            lineHeight: 1.4
                                        }
                                    }
                                }

                                // ── Siri waveform animation (loading state) ──
                                Item {
                                    Layout.fillWidth: true
                                    height: 36
                                    visible: aiLoading || aiStatus !== ""
                                    opacity: visible ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 300 } }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: aiStatus
                                        color: "#ff9f0a"
                                        font.pixelSize: 12
                                        font.italic: true
                                        visible: aiStatus !== ""
                                    }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        visible: aiLoading

                                        Repeater {
                                            model: 9
                                            delegate: Rectangle {
                                                width: 4
                                                radius: 2
                                                // Siri rainbow colors cycling across bars
                                                color: [
                                                    "#bf5af2", "#9d5af2", "#0a84ff",
                                                    "#0a84ff", "#30d158", "#30d158",
                                                    "#ffd60a", "#ff9f0a", "#ff375f"
                                                ][index]
                                                anchors.verticalCenter: parent.verticalCenter

                                                SequentialAnimation on height {
                                                    loops: Animation.Infinite
                                                    running: aiLoading
                                                    NumberAnimation {
                                                        to: 8 + Math.random() * 24
                                                        duration: 300 + index * 60
                                                        easing.type: Easing.InOutSine
                                                    }
                                                    NumberAnimation {
                                                        to: 4
                                                        duration: 300 + index * 60
                                                        easing.type: Easing.InOutSine
                                                    }
                                                }
                                                height: 4
                                            }
                                        }
                                    }
                                }

                                // ── AI Answer — scrollable Flickable ──
                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.min(answerFlick.contentHeight, 280)
                                    visible: !aiLoading && aiAnswer !== ""
                                    opacity: visible ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                                    clip: true

                                    Flickable {
                                        id: answerFlick
                                        anchors.fill: parent
                                        contentWidth: width
                                        contentHeight: answerCol.implicitHeight
                                        clip: true
                                        flickableDirection: Flickable.VerticalFlick
                                        ScrollBar.vertical: ScrollBar {
                                            policy: answerFlick.contentHeight > answerFlick.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                                            width: 4
                                            contentItem: Rectangle {
                                                radius: 2
                                                color: Qt.rgba(1, 1, 1, 0.25)
                                            }
                                            background: Item {}
                                        }

                                        ColumnLayout {
                                            id: answerCol
                                            width: answerFlick.width - 8
                                            spacing: 12

                                            Repeater {
                                                model: answerSegments

                                                delegate: ColumnLayout {
                                                    id: delegateRoot
                                                    Layout.fillWidth: true
                                                    spacing: 0

                                                    // Animate in when loaded
                                                    opacity: 0
                                                    transform: Translate { y: 10 }
                                                    Component.onCompleted: {
                                                        anim.start();
                                                    }
                                                    ParallelAnimation {
                                                        id: anim
                                                        NumberAnimation { target: delegateRoot; property: "opacity"; to: 1; duration: 400; easing.type: Easing.OutCubic }
                                                        NumberAnimation { target: delegateRoot.transform[0]; property: "y"; to: 0; duration: 400; easing.type: Easing.OutCubic }
                                                    }

                                                    // ── Text Segment ──
                                                    Text {
                                                        Layout.fillWidth: true
                                                        visible: modelData.type === "text"
                                                        text: visible ? modelData.content : ""
                                                        color: "#e8e8ed"
                                                        font.pixelSize: 13
                                                        font.family: "Inter, SF Pro Text, -apple-system, sans-serif"
                                                        lineHeight: 1.6
                                                        wrapMode: Text.WordWrap
                                                        textFormat: Text.MarkdownText
                                                        linkColor: "#0a84ff"
                                                        onLinkActivated: (link) => Qt.openUrlExternally(link)
                                                    }

                                                    // ── Code Segment ──
                                                    Rectangle {
                                                        Layout.fillWidth: true
                                                        implicitHeight: visible ? codeCol.implicitHeight + 20 : 0
                                                        visible: modelData.type === "code"
                                                        color: Qt.rgba(0.12, 0.12, 0.14, 1.0)
                                                        radius: 8
                                                        border.color: Qt.rgba(1, 1, 1, 0.08)
                                                        border.width: 1

                                                        // Left accent bar
                                                        Rectangle {
                                                            anchors.left: parent.left
                                                            anchors.top: parent.top
                                                            anchors.bottom: parent.bottom
                                                            width: 4
                                                            radius: 8
                                                            color: "#0a84ff"
                                                        }

                                                        ColumnLayout {
                                                            id: codeCol
                                                            anchors.left: parent.left
                                                            anchors.right: parent.right
                                                            anchors.top: parent.top
                                                            anchors.margins: 10
                                                            anchors.leftMargin: 14
                                                            spacing: 8

                                                            RowLayout {
                                                                Layout.fillWidth: true
                                                                Text {
                                                                    text: modelData.type === "code" ? (modelData.lang || "code") : ""
                                                                    color: Qt.rgba(1, 1, 1, 0.4)
                                                                    font.pixelSize: 11
                                                                    font.family: "JetBrains Mono, monospace"
                                                                }
                                                                Item { Layout.fillWidth: true }
                                                                
                                                                // Code copy button
                                                                Rectangle {
                                                                    width: codeCopyRow.implicitWidth + 12
                                                                    height: 20
                                                                    radius: 4
                                                                    color: codeCopyMA.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                                                    RowLayout {
                                                                        id: codeCopyRow
                                                                        anchors.centerIn: parent
                                                                        spacing: 4
                                                                        Text {
                                                                            text: codeCopyMA.copied ? "✓" : "⎘"
                                                                            color: codeCopyMA.copied ? "#30d158" : Qt.rgba(1,1,1,0.5)
                                                                            font.pixelSize: 10
                                                                        }
                                                                        Text {
                                                                            text: codeCopyMA.copied ? "Copied" : "Copy"
                                                                            color: codeCopyMA.copied ? "#30d158" : Qt.rgba(1,1,1,0.5)
                                                                            font.pixelSize: 10
                                                                        }
                                                                    }
                                                                    MouseArea {
                                                                        id: codeCopyMA
                                                                        anchors.fill: parent
                                                                        hoverEnabled: true
                                                                        cursorShape: Qt.PointingHandCursor
                                                                        property bool copied: false
                                                                        onClicked: {
                                                                            clipHelper.text = modelData.content.trim();
                                                                            clipHelper.selectAll();
                                                                            clipHelper.copy();
                                                                            copied = true;
                                                                            codeCopyResetTimer.restart();
                                                                        }
                                                                        Timer {
                                                                            id: codeCopyResetTimer
                                                                            interval: 2000
                                                                            onTriggered: codeCopyMA.copied = false
                                                                        }
                                                                    }
                                                                }
                                                            }

                                                            Text {
                                                                Layout.fillWidth: true
                                                                text: modelData.type === "code" ? modelData.content.trim() : ""
                                                                color: "#e8e8ed"
                                                                font.pixelSize: 12
                                                                font.family: "JetBrains Mono, monospace"
                                                                wrapMode: Text.WrapAnywhere
                                                                textFormat: Text.PlainText
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // ── Error text ──
                                Text {
                                    visible: !aiLoading && aiError !== ""
                                    opacity: visible ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 250 } }
                                    text: aiError
                                    color: "#ff375f"
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                // ── Bottom bar: copy button ──
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.bottomMargin: 2
                                    visible: !aiLoading && aiAnswer !== ""
                                    opacity: visible ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 250 } }
                                    
                                    TextField {
                                        id: aiFollowupField
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 30
                                        placeholderText: "Ask a follow-up..."
                                        color: "#f5f5f7"
                                        placeholderTextColor: Qt.rgba(1, 1, 1, 0.3)
                                        font.pixelSize: 13
                                        background: Rectangle {
                                            color: Qt.rgba(1, 1, 1, 0.05)
                                            radius: 15
                                            border.width: 1
                                            border.color: aiFollowupField.activeFocus ? Qt.rgba(0.0, 0.48, 1.0, 0.5) : Qt.rgba(1, 1, 1, 0.1)
                                        }
                                        leftPadding: 12
                                        rightPadding: 12
                                        onAccepted: {
                                            if (text.trim() !== "") {
                                                var q = text.trim();
                                                text = "";
                                                fetchAiAnswer(q, true);
                                            }
                                        }
                                    }



                                    Rectangle {
                                        id: copyBtn
                                        height: 26; radius: 13
                                        width: copyBtnRow.implicitWidth + 18
                                        color: copyMA.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.07)
                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        RowLayout {
                                            id: copyBtnRow
                                            anchors.centerIn: parent
                                            spacing: 5
                                            Text {
                                                text: copyMA.copied ? "✓" : "⎘"
                                                color: copyMA.copied ? "#30d158" : Qt.rgba(1,1,1,0.5)
                                                font.pixelSize: 11
                                                Behavior on color { ColorAnimation { duration: 200 } }
                                            }
                                            Text {
                                                text: copyMA.copied ? "Copied!" : "Copy"
                                                color: copyMA.copied ? "#30d158" : Qt.rgba(1,1,1,0.5)
                                                font.pixelSize: 11
                                                Behavior on color { ColorAnimation { duration: 200 } }
                                            }
                                        }

                                        MouseArea {
                                            id: copyMA
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            property bool copied: false
                                            onClicked: {
                                                clipHelper.text = aiAnswer;
                                                clipHelper.selectAll();
                                                clipHelper.copy();
                                                copied = true;
                                                copyResetTimer.restart();
                                            }
                                            Timer {
                                                id: copyResetTimer
                                                interval: 2000
                                                onTriggered: copyMA.copied = false
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: gridViewContainer
                        Layout.fillWidth: true
                        Layout.fillHeight: !isAiQuery(searchField.text)
                        Layout.preferredHeight: isAiQuery(searchField.text) ? 0 : -1
                        Layout.margins: isAiQuery(searchField.text) ? 0 : 14
                        visible: layoutSettings.isGridView && searchField.text !== "" && !isAiQuery(searchField.text)
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        GridView {
                            id: gridResults
                            anchors.fill: parent
                            clip: true
                            cellWidth: Math.floor(width / 6)
                            cellHeight: 116

                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                                width: 6
                                contentItem: Rectangle { radius: 3; color: Qt.rgba(1, 1, 1, 0.25) }
                                background: Item {}
                            }

                            model: isFolderPath(searchField.text) ? folderModel : (runnerModel.count > 0 ? runnerModel.modelForRow(0) : null)

                            function triggerCurrent() {
                                var idx = currentIndex >= 0 ? currentIndex : 0;
                                var m = isFolderPath(searchField.text) ? folderModel : (runnerModel.count > 0 ? runnerModel.modelForRow(0) : null);
                                if (!m) return;
                                
                                if (isFolderPath(searchField.text)) {
                                    if (idx < folderModel.count) {
                                        var fileUrl = folderModel.get(idx, "fileUrl");
                                        var isDir = folderModel.get(idx, "fileIsDir");
                                        if (isDir) {
                                            searchField.text = fileUrl.toString().replace("file://", "");
                                        } else {
                                            Qt.openUrlExternally(fileUrl);
                                            closeAnim.restart();
                                        }
                                    }
                                } else {
                                    if (m.trigger) {
                                        m.trigger(idx, "", null);
                                        closeAnim.restart();
                                    }
                                }
                            }


                            Keys.onSpacePressed: (event) => {
                                if (currentItem && currentItem.normUrl) {
                                    var res = currentItem.normUrl.toString();
                                    var c = res.toLowerCase();
                                    if (c.endsWith(".png") || c.endsWith(".jpg") || c.endsWith(".jpeg") || c.endsWith(".svg") || c.endsWith(".gif") || c.endsWith(".webp") || c.endsWith(".bmp")) {
                                        previewImage.source = res;
                                        previewOverlay.visible = true;
                                        event.accepted = true;
                                    }
                                }
                            }

                            Keys.onReleased: (event) => {
                                if (event.key === Qt.Key_Space) {
                                    previewOverlay.visible = false;
                                    event.accepted = true;
                                }
                            }

                            Keys.onReturnPressed: triggerCurrent()
                            Keys.onEnterPressed: triggerCurrent()
                            Keys.onEscapePressed: {
                                if (previewOverlay.visible) {
                                    previewOverlay.visible = false;
                                } else {
                                    searchField.forceActiveFocus();
                                }
                            }

                            delegate: Item {
                                width: gridResults.cellWidth
                                height: gridResults.cellHeight

                                property bool isSelected: gridResults.currentIndex === index
                                property bool isHovered: gridMouseArea.containsMouse

                                property string normName: model.fileName !== undefined ? model.fileName : (model.display !== undefined ? model.display : "")
                                property string normDesc: model.description !== undefined ? model.description : ""
                                property bool normIsDir: model.fileIsDir !== undefined ? model.fileIsDir : false
                                property string normIcon: model.decoration !== undefined ? model.decoration : (normIsDir ? "folder" : "document")
                                property string normUrl: {
                                    if (model.fileUrl !== undefined && model.fileUrl !== "") return model.fileUrl.toString();
                                    if (model.url !== undefined && model.url !== "") return model.url.toString();
                                    var d = model.description;
                                    if (d !== undefined && (d.startsWith("/") || d.startsWith("~"))) {
                                        return "file://" + (d.startsWith("~") ? StandardPaths.writableLocation(StandardPaths.HomeLocation) + d.substring(1) : d);
                                    }
                                    return "";
                                }


                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 5
                                    color: isSelected ? Qt.rgba(0.0, 0.48, 1.0, 0.85) : (isHovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                    radius: 12
                                    scale: isHovered && !isSelected ? 1.02 : 1.0
                                    border.width: isSelected ? 1 : 0
                                    border.color: Qt.rgba(1, 1, 1, 0.55)

                                    // White glow for selected grid item
                                    layer.enabled: isSelected
                                    layer.effect: null

                                    Repeater {
                                        model: isSelected ? 3 : 0
                                        delegate: Rectangle {
                                            anchors.centerIn: parent
                                            width: parent.width + index * 6
                                            height: parent.height + index * 6
                                            radius: parent.radius + index * 3
                                            color: "transparent"
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.18 - index * 0.05)
                                        }
                                    }

                                    Behavior on color { ColorAnimation { duration: 130; easing.type: Easing.OutQuad } }
                                    Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutQuad } }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 6

                                        Item {
                                            Layout.preferredWidth: 64
                                            Layout.preferredHeight: 64
                                            Layout.alignment: Qt.AlignHCenter

                                            property string fileExt: normUrl.split('.').pop().toLowerCase()
                                            property bool isImage: !normIsDir && (fileExt === "png" || fileExt === "jpg" || fileExt === "jpeg" || fileExt === "svg")

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 8
                                                color: "transparent"
                                                visible: parent.isImage

                                                Image {
                                                    anchors.fill: parent
                                                    anchors.margins: 1
                                                    source: parent.parent.isImage ? normUrl : ""
                                                    fillMode: Image.PreserveAspectCrop
                                                    sourceSize: Qt.size(64, 64)
                                                    asynchronous: true
                                                    layer.enabled: true
                                                }
                                            }

                                            Kirigami.Icon {
                                                anchors.fill: parent
                                                source: normIcon
                                                visible: !parent.isImage
                                            }
                                        }

                                        Text {
                                            text: normName
                                            color: "#f5f5f7"
                                            font.family: "SF Pro Text, Inter, sans-serif"
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            elide: Text.ElideMiddle
                                            horizontalAlignment: Text.AlignHCenter
                                            Layout.fillWidth: true
                                        }
                                    }

                                    MouseArea {
                                        id: gridMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: {
                                            if (!normIsDir && normUrl) {
                                                root.currentHoveredUrl = normUrl;
                                            } else {
                                                root.currentHoveredUrl = "";
                                            }
                                        }
                                        onExited: { root.currentHoveredUrl = ""; }
                                        onClicked: {
                                            gridResults.currentIndex = index;
                                            gridResults.triggerCurrent();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        Layout.margins: 10
                        radius: 10
                        color: Qt.rgba(0.0, 0.48, 1.0, 0.85)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.50)
                        property bool hasResults: layoutSettings.isGridView ? gridResults.count > 0 : searchResults.count > 0
                        visible: !hasResults && searchField.text !== "" && !isAiQuery(searchField.text)
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8
                            Text {
                                text: "✦"
                                color: "white"
                                font.pixelSize: 16
                            }
                            Text {
                                text: "Ask AI: " + searchField.text
                                color: "white"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: "Press Enter ↵"
                                color: Qt.rgba(1, 1, 1, 0.7)
                                font.pixelSize: 11
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var q = searchField.text.trim();
                                searchField.text = "/ai " + q;
                                fetchAiAnswer(q);
                            }
                        }
                    }

                    ListView {
                        id: searchResults
                        Layout.fillWidth: true
                        Layout.fillHeight: !isAiQuery(searchField.text)
                        Layout.preferredHeight: isAiQuery(searchField.text) ? 0 : -1
                        Layout.margins: isAiQuery(searchField.text) ? 0 : 10
                        clip: true
                        spacing: 1
                        visible: !layoutSettings.isGridView && searchField.text !== "" && !isAiQuery(searchField.text)
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 6
                            contentItem: Rectangle { radius: 3; color: Qt.rgba(1, 1, 1, 0.25) }
                            background: Item {}
                        }

                        model: isFolderPath(searchField.text) ? folderModel : (runnerModel.count > 0 ? runnerModel.modelForRow(0) : null)

                        function triggerCurrent() {
                                var idx = currentIndex >= 0 ? currentIndex : 0;
                                var m = isFolderPath(searchField.text) ? folderModel : (runnerModel.count > 0 ? runnerModel.modelForRow(0) : null);
                                if (!m) return;
                                
                                if (isFolderPath(searchField.text)) {
                                    if (idx < folderModel.count) {
                                        var fileUrl = folderModel.get(idx, "fileUrl");
                                        var isDir = folderModel.get(idx, "fileIsDir");
                                        if (isDir) {
                                            searchField.text = fileUrl.toString().replace("file://", "");
                                        } else {
                                            Qt.openUrlExternally(fileUrl);
                                            closeAnim.restart();
                                        }
                                    }
                                } else {
                                    if (m.trigger) {
                                        m.trigger(idx, "", null);
                                        closeAnim.restart();
                                    }
                                }
                            }

                        Keys.onSpacePressed: (event) => {
                            if (currentItem && currentItem.itemUrl) {
                                var res = currentItem.itemUrl.toString();
                                var c = res.toLowerCase();
                                if (c.endsWith(".png") || c.endsWith(".jpg") || c.endsWith(".jpeg") || c.endsWith(".svg") || c.endsWith(".gif") || c.endsWith(".webp") || c.endsWith(".bmp")) {
                                    previewImage.source = res;
                                    previewOverlay.visible = true;
                                    event.accepted = true;
                                }
                            }
                        }

                        Keys.onReleased: (event) => {
                            if (event.key === Qt.Key_Space) {
                                previewOverlay.visible = false;
                                event.accepted = true;
                            }
                        }

                        Keys.onReturnPressed: triggerCurrent()
                        Keys.onEnterPressed: triggerCurrent()
                        Keys.onEscapePressed: { searchField.forceActiveFocus() }

                        delegate: Item {
                            width: ListView.view.width
                            height: 52



                            property bool isSelected: searchResults.currentIndex === index
                            property bool isHovered: listMouseArea.containsMouse

                                property string normName: model.fileName !== undefined ? model.fileName : (model.display !== undefined ? model.display : "")
                                property string normDesc: model.description !== undefined ? model.description : ""
                                property bool normIsDir: model.fileIsDir !== undefined ? model.fileIsDir : false
                                property string normIcon: model.decoration !== undefined ? model.decoration : (normIsDir ? "folder" : "document")
                                property string normUrl: {
                                    if (model.fileUrl !== undefined && model.fileUrl !== "") return model.fileUrl.toString();
                                    if (model.url !== undefined && model.url !== "") return model.url.toString();
                                    var d = model.description;
                                    if (d !== undefined && (d.startsWith("/") || d.startsWith("~"))) {
                                        return "file://" + (d.startsWith("~") ? StandardPaths.writableLocation(StandardPaths.HomeLocation) + d.substring(1) : d);
                                    }
                                    return "";
                                }


                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                radius: 10
                                color: isSelected ? Qt.rgba(0.0, 0.48, 1.0, 0.85) : (isHovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                                border.width: isSelected ? 1 : 0
                                border.color: Qt.rgba(1, 1, 1, 0.50)

                                // White glow rings for selected list item
                                Repeater {
                                    model: isSelected ? 3 : 0
                                    delegate: Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width + index * 6
                                        height: parent.height + index * 6
                                        radius: parent.radius + index * 3
                                        color: "transparent"
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.15 - index * 0.04)
                                    }
                                }

                                Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutQuad } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 14
                                    spacing: 12

                                    Kirigami.Icon {
                                        source: normIcon
                                        Layout.preferredWidth: 30
                                        Layout.preferredHeight: 30
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: normName
                                            color: "#f5f5f7"
                                            font.family: "SF Pro Text, Inter, sans-serif"
                                            font.pixelSize: 14
                                            font.weight: Font.Normal
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: normDesc
                                            color: isSelected || isHovered ? Qt.rgba(1, 1, 1, 0.88) : Qt.rgba(1, 1, 1, 0.42)
                                            font.family: "SF Pro Text, Inter, sans-serif"
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                            visible: text !== ""
                                        }
                                    }

                                    Text {
                                        text: "↵"
                                        color: Qt.rgba(1, 1, 1, 0.55)
                                        font.pixelSize: 13
                                        visible: isSelected
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                }

                                MouseArea {
                                    id: listMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: { root.currentHoveredUrl = normUrl; }
                                    onExited: { root.currentHoveredUrl = ""; }
                                    onClicked: {
                                        searchResults.currentIndex = index;
                                        searchResults.triggerCurrent();
                                    }
                                }
                            }
                        }
                    }

                    // Bottom hint bar — macOS Spotlight always shows this row
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        color: Qt.rgba(0, 0, 0, 0.15)
                        visible: searchField.text !== ""
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 180 } }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.06)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 18

                            Item { Layout.fillWidth: true }

                            RowLayout {
                                spacing: 5
                                Text { text: "↵"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 11 }
                                Text { text: "Open"; color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 10 }
                            }

                            RowLayout {
                                spacing: 5
                                Text { text: "␣"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 11 }
                                Text { text: "Preview"; color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 10 }
                            }

                            RowLayout {
                                spacing: 5
                                Text { text: "esc"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 10 }
                                Text { text: "Close"; color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 10 }
                            }
                        }
                    }
                }

                Rectangle {
                    id: previewOverlay
                    anchors.fill: parent
                    color: Qt.rgba(0.05, 0.05, 0.06, 0.92)
                    radius: searchContainer.radius
                    visible: false
                    z: 99
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }

                    Image {
                        id: previewImage
                        anchors.fill: parent
                        anchors.margins: 28
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        layer.enabled: true
                    }
                }
            }
        }
    }}
