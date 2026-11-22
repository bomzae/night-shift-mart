---
name: godot-testing
description: NIGHT SHIFT MART에서 Godot 실행, 임포트, 신규 자동 검사 및 기존 Prompt 회귀 검사를 수행할 때 사용한다.
---
# Godot Testing

## Godot Version
Project: `C:\Users\user\orca\workspaces\ProjectA\develop`
Godot: `D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`

Godot 4.7.2 stable. PROJECT_NOTES.md에 기록된 정확한 기존 ZIP 실행 파일 절대 경로를 사용한다. godot PATH 검색, 새 버전 설치, 실행 파일 이름 변경을 하지 않는다.

## Regression First
기존 Prompt 0~5 및 이후 추가된 검사를 유지한다. 검사를 삭제하거나 통과시키기 위해 의미를 약화하지 않는다. 테스트 fixture 변경이 필요하면 원인과 검사 계약 보존 근거를 기록한다.

## Physics Test Rule
단일 정확한 좌표 대신 목적에 맞는 tolerance/상대 비교를 쓴다. 산포와 기능 오류를 구분하며 실패 로그를 보존한다. 실패 시 초기 조건·접촉·입력·포커스를 조사하고 성공할 때까지 무조건 반복하지 않는다.

## Test Order
가능하면 Project import → 신규 기능 검사 → 기존 Regression → Main 실행 → 오류 로그 확인 순서다. 명령과 스크립트 목록은 PROJECT_NOTES.md를 참고한다.
Prompt 13.3 사용자 지시부터 자동 검사는 headless 우선, window 실행은 최종 smoke 1회로 제한한다. OS mouse/focus는 pass/fail 조건으로 삼지 않는다. `tests/run_headless.ps1`은 `.godot/headless_<tag>`의 별도 복사본에서 mouse capture 상태만 모의하고 screenshot 대기를 생략한다. 실제 입력 이벤트·물리·assertion은 유지하고 원본 gameplay 코드는 변경하지 않는다. 합성 MouseMotion은 viewport 로컬 좌표로 전달한다. 창 실행 전 시각 fixture를 `--headless --check-only --script <script>`로 먼저 검사한다. 이 검증과 실제 화면 렌더링 smoke를 구분해 보고한다. SCRIPT ERROR/ERROR:/FAIL:와 종료 결과를 확인하며 정상 측정값 error_after_*와 혼동하지 않는다.
Godot 씬/스크립트는 UTF-8 BOM 없이 저장한다.

## Manual Tests
자동 검사로 Gameplay feel을 확정하지 않는다. Completion Report에 실제 검사 결과와 수동 조작 절차·알려진 문제를 구분해 적는다.

## Godot Test Authorization
For this project, Godot test execution is pre-authorized by the user.
Do not ask for confirmation before normal project validation: import checks, headless smoke tests, windowed Prompt smoke tests, regression tests, Main scene simulations, test scenes, and log validation. Use the documented Godot executable path.
Only ask if an action goes beyond normal project testing or the execution environment explicitly requires approval. This does not bypass environment permissions or weaken test criteria.
After implementation, automatically run relevant new tests, the regression suite, and Main simulation; inspect logs and report results. Do not ask “테스트 실행해도 될까요?”.
