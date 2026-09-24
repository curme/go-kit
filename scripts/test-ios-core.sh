#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build/native/module-cache
swiftc -whole-module-optimization -module-cache-path .build/native/module-cache \
  ios/GoKit/Core/GoEngine.swift ios/GoKit/Core/Lesson.swift \
  ios/GoKit/Core/Curriculum.swift ios/GoKit/Core/AdvancedCurriculum.swift \
  ios/GoKit/Core/PracticeGame.swift ios/GoKit/Core/CoachTraining.swift \
  ios/GoKit/Core/WuCurriculum.swift ios/GoKit/Core/HundredDayPlan.swift \
  ios/GoKit/Core/StudyCourse.swift ios/GoKit/Core/StudyContent.swift \
  ios/GoKit/Core/StudyDiagrams.swift ios/GoKit/Core/StudyPractice.swift \
  ios/Tests/StudyTests.swift \
  ios/GoKit/AppStore.swift ios/Tests/EngineTests.swift ios/Tests/CoachTests.swift \
  -o .build/native/engine-tests
.build/native/engine-tests
