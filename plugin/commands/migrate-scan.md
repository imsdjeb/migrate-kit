---
description: "Scan your project to detect the current framework version, find deprecated APIs, and assess migration complexity."
argument-hint: "[target-version] e.g. 19 or angular@19 or latest"
---

Run the **SCAN** phase from the migrate-kit skill. Detect the current framework and version, calculate the version gap to the target, scan for deprecated API usage, and output a complexity assessment.

If the user provided a target version, use it. Otherwise, detect the latest stable version.
