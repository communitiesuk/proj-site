---
title: The project's own tests give the same result on every pull request
date: 2026-11-25
theme: Pilot
refs: ["plans/0001-project-site.md"]
---
The project's test suite had been failing on every pull request while passing
everywhere else: some tests picked up details of the pull request they were
running on, which differ from the test's own setup. The tests now run without
those details, so a failure on a pull request means a real problem, and a new
test keeps it that way.
