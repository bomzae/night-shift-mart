---
name: bug-fix
description: NIGHT SHIFT MART 기존 기능의 사용자 보고 버그를 재현하고 최소 수정 및 회귀 검사할 때 사용한다.
---
# Bug Fix

## Reproduce First
현재 동작과 관련 코드 경로를 확인하고 원인 가설을 검증한다. 가능하면 수정 전 실패하는 재현 검사를 만들고 수정 후 같은 계약을 검사한다.

## Minimal Fix
필요 없는 시스템을 리팩터링하지 않는다. Grab/Throw/Cart/Delivery/Stock/Checkout/Customer/Drunk를 이유 없이 다시 작성하지 않는다. 정상 데이터 계약과 상호작용을 유지한다.

## Preserve Emergent Behavior
예상 밖 물리 행동이 재미일 수 있다. 사용자가 버그로 지정했거나 gameplay 영향을 분석한 문제를 수정한다. 카트를 대상에 밀착해 비빌 때 반복 Damage가 발생하는 Known Issue는 현재 수정하지 않으며 전투 시스템 완성 후 다시 평가한다.

## Regression
수정 후 관련 신규 검사와 기존 회귀 검사를 실행한다. Godot 실행은 godot-testing Skill을 함께 읽는다. 원인·수정·실패/재실행·남은 문제를 문서와 보고에 기록한다.
