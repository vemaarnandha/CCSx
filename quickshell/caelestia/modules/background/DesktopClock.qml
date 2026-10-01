pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

Item {
    id: root

    required property Item wallpaper
    required property real absX
    required property real absY

    property real clockScale: Config.background.desktopClock.scale
    readonly property bool bgEnabled: Config.background.desktopClock.background.enabled
    readonly property bool blurEnabled: bgEnabled && Config.background.desktopClock.background.blur && !GameMode.enabled
    readonly property bool invertColors: Config.background.desktopClock.invertColors
    readonly property bool useLightSet: Colours.light ? !invertColors : invertColors
    readonly property color safePrimary: useLightSet ? Colours.palette.m3primaryContainer : Colours.palette.m3primary
    readonly property color safeSecondary: useLightSet ? Colours.palette.m3secondaryContainer : Colours.palette.m3secondary
    readonly property color safeTertiary: useLightSet ? Colours.palette.m3tertiaryContainer : Colours.palette.m3tertiary
    readonly property string timeLine: Units.twelveHourClock ? `- ${Time.hourStr}:${Time.minuteStr} ${Time.amPmStr} -` : `- ${Time.timeStr} -`
    readonly property string clockFamily: "Lincoln Electric"
    readonly property string clockStyle: "Over"

    implicitWidth: layout.implicitWidth + (Tokens.padding.large * 4 * root.clockScale)
    implicitHeight: layout.implicitHeight + (Tokens.padding.extraLargeIncreased * root.clockScale)

    Item {
        id: clockContainer

        anchors.fill: parent

        layer.enabled: Config.background.desktopClock.shadow.enabled
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Colours.palette.m3shadow
            shadowOpacity: Config.background.desktopClock.shadow.opacity
            shadowBlur: Config.background.desktopClock.shadow.blur
        }

        Loader {
            asynchronous: true
            anchors.fill: parent
            active: root.blurEnabled

            sourceComponent: MultiEffect {
                source: ShaderEffectSource {
                    sourceItem: root.wallpaper
                    sourceRect: Qt.rect(root.absX, root.absY, root.width, root.height)
                }
                maskSource: backgroundPlate
                maskEnabled: true
                blurEnabled: true
                blur: 1
                blurMax: 64
                autoPaddingEnabled: false
            }
        }

        StyledRect {
            id: backgroundPlate

            visible: root.bgEnabled
            anchors.fill: parent
            radius: Tokens.rounding.extraLarge * root.clockScale
            opacity: Config.background.desktopClock.background.opacity
            color: Colours.palette.m3surface

            layer.enabled: root.blurEnabled
        }

        ColumnLayout {
            id: layout

            anchors.centerIn: parent
            spacing: Tokens.spacing.small * root.clockScale

            StyledText {
                text: Time.format("dddd").toUpperCase()
                font.family: root.clockFamily
                font.styleName: root.clockStyle
                font.pointSize: Tokens.font.headline.medium.pointSize * 1.5 * root.clockScale
                font.letterSpacing: 6 * root.clockScale
                color: root.safePrimary
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: root.safePrimary
                    shadowOpacity: 1
                    shadowBlur: 1
                }
            }

            StyledText {
                text: Time.format("dd MMMM, yyyy.").toUpperCase()
                font.family: Tokens.font.title.medium.family
                font.pointSize: Tokens.font.title.medium.pointSize * root.clockScale
                font.letterSpacing: 2
                font.weight: Font.Bold
                color: root.safeSecondary
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: root.safeSecondary
                    shadowOpacity: 1
                    shadowBlur: 1
                }
            }

            StyledText {
                text: root.timeLine
                font.family: Tokens.font.body.large.family
                font.pointSize: Tokens.font.body.large.pointSize * root.clockScale
                font.letterSpacing: 3
                font.weight: Font.Bold
                color: root.safeSecondary
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: root.safeSecondary
                    shadowOpacity: 1
                    shadowBlur: 1
                }
            }
        }
    }

    Behavior on clockScale {
        Anim {}
    }

    Behavior on implicitWidth {
        Anim {
            type: Anim.StandardSmall
        }
    }
}
