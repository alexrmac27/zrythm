// SPDX-FileCopyrightText: © 2026 Alexandros Theodotou <alex@zrythm.org>
// SPDX-License-Identifier: LicenseRef-ZrythmLicense

import QtQuick
import QtQuick.Controls
import QtTest
import Zrythm

TestCase {
  id: test

  name: "DrumStepGrid"
  Component {
    id: windowComponent

    ApplicationWindow {
      property alias grid: grid

      width: 900
      height: 200
      visible: true

      DrumStepGrid {
        id: grid

        drumRows: [{ name: "Kick", pitch: 36 }, { name: "Snare", pitch: 38 }]
        enabledSteps: 12
        stepCounts: []
      }
    }
  }

  SignalSpy {
    id: activationSpy
    signalName: "stepActivated"
  }

  property ApplicationWindow window: null
  property var grid: window ? window.grid : null

  function init() {
    window = windowComponent.createObject(null);
    tryVerify(() => window.visible);
    activationSpy.target = grid;
  }

  function cleanup() {
    activationSpy.target = null;
    window.destroy();
    window = null;
  }

  function findVisualChild(item, name) {
    if (item.objectName === name)
      return item;
    for (const child of item.children) {
      const result = findVisualChild(child, name);
      if (result)
        return result;
    }
    return null;
  }

  function test_grid_state_and_activation() {
    const active = findVisualChild(grid, "drumStep-0-0");
    const disabled = findVisualChild(grid, "drumStep-0-12");
    const snare = findVisualChild(grid, "drumStep-1-2");
    verify(active);
    verify(disabled);
    verify(snare);
    verify(!active.checked);
    verify(!disabled.enabled);

    const counts = Array(32).fill(0);
    counts[0] = 2;
    grid.stepCounts = counts;
    tryCompare(active, "checked", true);
    compare(active.text, "+");

    mouseClick(snare);
    compare(activationSpy.count, 1);
    compare(activationSpy.signalArguments[0][0], 38);
    compare(activationSpy.signalArguments[0][1], 2);
  }
}
