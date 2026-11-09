// SPDX-FileCopyrightText: © 2026 Alexandros Theodotou <alex@zrythm.org>
// SPDX-License-Identifier: LicenseRef-ZrythmLicense

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
  id: root

  required property var drumRows
  required property int enabledSteps
  required property var stepCounts

  signal stepActivated(int pitch, int step)

  Repeater {
    model: root.drumRows

    delegate: RowLayout {
      id: drumRow

      required property int index
      required property var modelData

      Label {
        Layout.preferredWidth: 105
        text: drumRow.modelData.name
      }

      Repeater {
        model: 16

        delegate: Button {
          required property int index

          Accessible.name: qsTr("%1, step %2").arg(drumRow.modelData.name).arg(index + 1)
          Layout.preferredWidth: 32
          checkable: true
          checked: (root.stepCounts[drumRow.index * 16 + index] ?? 0) > 0
          enabled: index < root.enabledSteps
          objectName: "drumStep-" + drumRow.index + "-" + index
          text: (root.stepCounts[drumRow.index * 16 + index] ?? 0) > 1 ? "+" : ""

          onClicked: root.stepActivated(drumRow.modelData.pitch, index)
        }
      }
    }
  }
}
