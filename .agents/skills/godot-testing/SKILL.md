---
name: godot-testing
description: NIGHT SHIFT MART에서 Godot 실행, 임포트, 신규 자동 검사 및 기존 Prompt 회귀 검사를 수행할 때 사용한다.
---
# Godot Testing

## Godot Version
Godot 4.7.2 stable. PROJECT_NOTES.md에 기록된 정확한 기존 ZIP 실행 파일 절대 경로를 사용한다. godot PATH 검색, 새 버전 설치, 실행 파일 이름 변경을 하지 않는다.

## Regression First
기존 Prompt 0~5 및 이후 추가된 검사를 유지한다. 검사를 삭제하거나 통과시키기 위해 의미를 약화하지 않는다. 테스트 fixture 변경이 필요하면 원인과 검사 계약 보존 근거를 기록한다.

## Physics Test Rule
단일 정확한 좌표 대신 목적에 맞는 tolerance/상대 비교를 쓴다. 산포와 기능 오류를 구분하며 실패 로그를 보존한다. 실패 시 초기 조건·접촉·입력·포커스를 조사하고 성공할 때까지 무조건 반복하지 않는다.

## Test Order
가능하면 Project import → 신규 기능 검사 → 기존 Regression → Main 실행 → 오류 로그 확인 순서다. 명령과 스크립트 목록은 PROJECT_NOTES.md를 참고한다.
입력 테스트는 실제 창에서 순차 실행한다. 동시에 여러 창을 띄우거나 검사 중 입력/Alt+Tab하지 않는다. Headless는 임포트/Main 검사에 사용한다. SCRIPT ERROR/ERROR:/FAIL:와 종료 결과를 확인하며 정상 측정값 error_after_*와 혼동하지 않는다.
Godot 씬/스크립트는 UTF-8 BOM 없이 저장한다.

## Manual Tests
자동 검사로 Gameplay feel을 확정하지 않는다. Completion Report에 실제 검사 결과와 수동 조작 절차·알려진 문제를 구분해 적는다.

## Godot Test Authorization
For this project, Godot test execution is pre-authorized by the user.
Do not ask for confirmation before normal project validation: import checks, headless smoke tests, windowed Prompt smoke tests, regression tests, Main scene simulations, test scenes, and log validation. Use the documented Godot executable path.
Only ask if an action goes beyond normal project testing or the execution environment explicitly requires approval. This does not bypass environment permissions or weaken test criteria.
After implementation, automatically run relevant new tests, the regression suite, and Main simulation; inspect logs and report results. Do not ask “테스트 실행해도 될까요?”.
