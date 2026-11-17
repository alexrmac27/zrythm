// SPDX-FileCopyrightText: © 2026 Alexandros Theodotou <alex@zrythm.org>
// SPDX-License-Identifier: LicenseRef-ZrythmLicense

import QtQuick
import QtTest
import Zrythm

TestCase {
  name: "PluginSearchMatcher"

  PluginSearchMatcher {
    id: matcher
  }

  function test_search() {
    verify(matcher.matches("", "Surge XT", "Surge Synth Team", "Instrument", "VST3"));
    verify(matcher.matches("  ", "Surge XT", "Surge Synth Team", "Instrument", "VST3"));
    verify(matcher.matches("surge", "Surge XT", "Surge Synth Team", "Instrument", "VST3"));
    verify(matcher.matches("SYNTH vst3", "Surge XT", "Surge Synth Team", "Instrument", "VST3"));
    verify(matcher.matches("instrument team", "Surge XT", "Surge Synth Team", "Instrument", "VST3"));
    verify(!matcher.matches("vst3 delay", "Surge XT", "Surge Synth Team", "Instrument", "VST3"));
    verify(!matcher.matches("surge clap", "Surge XT", "Surge Synth Team", "Instrument", "VST3"));
  }
}
