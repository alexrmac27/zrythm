// SPDX-FileCopyrightText: © 2026 Alexandros Theodotou <alex@zrythm.org>
// SPDX-License-Identifier: LicenseRef-ZrythmLicense

import QtQuick

QtObject {
  function matches(query: string, name: string, vendor: string, category: string, format: string): bool {
    const terms = query.toLowerCase().trim().split(/\s+/).filter(term => term.length > 0);
    const fields = [name, vendor, category, format].map(field => field.toLowerCase());
    return terms.every(term => fields.some(field => field.includes(term)));
  }
}
