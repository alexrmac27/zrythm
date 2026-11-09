// SPDX-FileCopyrightText: © 2026 Alexandros Theodotou <alex@zrythm.org>
// SPDX-License-Identifier: LicenseRef-ZrythmLicense

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Zrythm
import ZrythmGui

Dialog {
  id: root

  required property MidiClip midiClip
  required property ArrangerObjectCreator objectCreator
  required property ArrangerObjectSelectionOperator selectionOperator
  required property TempoMap tempoMap

  readonly property var drumRows: [
    { name: qsTr("Kick"), pitch: 36 },
    { name: qsTr("Snare"), pitch: 38 },
    { name: qsTr("Clap"), pitch: 39 },
    { name: qsTr("Closed Hat"), pitch: 42 },
    { name: qsTr("Open Hat"), pitch: 46 },
    { name: qsTr("Low Tom"), pitch: 45 },
    { name: qsTr("High Tom"), pitch: 50 },
    { name: qsTr("Rim"), pitch: 37 }
  ]
  readonly property real firstTick: root.midiClip ? root.midiClip.clipStartPosition.ticks : 0
  readonly property real endTick: root.midiClip ? Math.min(root.midiClip.loopEndPosition.ticks, root.firstTick + root.midiClip.length.ticks) : 0
  readonly property real stepLength: root.tempoMap ? root.tempoMap.getPpq() / 4 : 1
  readonly property int totalSteps: Math.max(0, Math.floor((root.endTick - root.firstTick) / root.stepLength))
  property int page: 0
  property var stepCounts: []

  function noteAt(pitch: int, tick: real): MidiNote {
    const notes = root.midiClip.midiNotes;
    for (let i = 0; i < notes.rowCount(); ++i) {
      const note = notes.data(notes.index(i, 0), ArrangerObjectListModel.ArrangerObjectPtrRole) as MidiNote;
      if (note && note.pitch === pitch && Math.abs(note.position.ticks - tick) < 0.001)
        return note;
    }
    return null;
  }

  function refreshSteps() {
    if (!root.midiClip || !root.tempoMap)
      return;
    const counts = Array(root.drumRows.length * 16).fill(0);
    const notes = root.midiClip.midiNotes;
    for (let i = 0; i < notes.rowCount(); ++i) {
      const note = notes.data(notes.index(i, 0), ArrangerObjectListModel.ArrangerObjectPtrRole) as MidiNote;
      if (!note)
        continue;
      const stepFloat = (note.position.ticks - root.firstTick) / root.stepLength - root.page * 16;
      const step = Math.round(stepFloat);
      if (step < 0 || step >= 16 || Math.abs(stepFloat - step) * root.stepLength >= 0.001)
        continue;
      const row = root.drumRows.findIndex(drum => drum.pitch === note.pitch);
      if (row >= 0)
        counts[row * 16 + step]++;
    }
    root.stepCounts = counts;
  }

  function toggleStep(pitch: int, step: int) {
    const tick = root.firstTick + (root.page * 16 + step) * root.stepLength;
    const note = root.noteAt(pitch, tick);
    if (note) {
      if (!root.selectionOperator.deleteObject(note)) {
        console.warn("Could not remove drum note");
        root.refreshSteps();
      }
    } else if (!root.objectCreator.addMidiNoteWithLength(root.midiClip, tick, root.stepLength, pitch, 90)) {
      console.warn("Could not create drum note");
      root.refreshSteps();
    }
  }

  title: qsTr("Drum Step Sequencer")
  implicitWidth: 720
  implicitHeight: 420
  modal: true
  popupType: Popup.Window
  standardButtons: Dialog.Close

  onOpened: root.refreshSteps()
  onMidiClipChanged: {
    if (root.visible) {
      root.page = 0;
      root.refreshSteps();
    }
  }
  onPageChanged: root.refreshSteps()
  onFirstTickChanged: root.refreshSteps()
  onTotalStepsChanged: {
    root.page = Math.min(root.page, Math.max(0, Math.ceil(root.totalSteps / 16) - 1));
    root.refreshSteps();
  }

  Connections {
    function onContentChanged() {
      root.refreshSteps();
    }

    target: root.midiClip
  }

  contentItem: ColumnLayout {
    Label {
      Layout.fillWidth: true
      text: qsTr("Edit sixteenth notes in the clip. Connect a drum instrument to hear them. A + marks overlapping notes; each click removes one.")
      wrapMode: Text.Wrap
    }

    ScrollView {
      Layout.fillHeight: true
      Layout.fillWidth: true
      implicitHeight: 300
      implicitWidth: 700

      DrumStepGrid {
        drumRows: root.drumRows
        enabledSteps: Math.max(0, Math.min(16, root.totalSteps - root.page * 16))
        stepCounts: root.stepCounts

        onStepActivated: (pitch, step) => root.toggleStep(pitch, step)
      }
    }

    RowLayout {
      Button {
        enabled: root.page > 0
        text: qsTr("Previous")
        onClicked: root.page--
      }
      Label {
        text: root.totalSteps > 0 ? qsTr("Steps %1–%2").arg(root.page * 16 + 1).arg(Math.min((root.page + 1) * 16, root.totalSteps)) : qsTr("No complete steps in this clip")
      }
      Button {
        enabled: (root.page + 1) * 16 < root.totalSteps
        text: qsTr("Next")
        onClicked: root.page++
      }
    }
  }
}
