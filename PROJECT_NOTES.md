# NIGHT SHIFT MART — 개발 메모

후속 Codex/Astra 작업은 이 문서부터 읽고 현재 단계와 범위를 확인한다.

## 다음 세션을 위한 인수인계 — 2026-09-29

**현재 기준은 Prompt 5 완료 상태다. 다음 기능 후보는 Lost Child이며 아직 구현하지 않았다.** 이 문서는 현재 구현 사실, 이전 검증 기록, 다음 작업 제안을 구분한다. 아래 과거 단계의 수치는 당시 기록이며 최신 전체 결과는 **327개 통과**다.

이번 인수인계 작업에서는 실제 파일과 보관된 최종 로그를 읽어 문서만 보완했다. 게임 코드를 변경하거나 Godot 검사를 새로 실행하지 않았다. 아래 통과 결과는 직전 Prompt 5 구현 종료 시 실행한 기록이다. 자동 검사의 입력·물리 검증과 화면 확인을 사람이 장시간 직접 플레이한 결과로 해석하지 않는다.

### 1. 현재 작업 위치와 즉시 재개 순서

- 프로젝트 루트: `C:\Users\user\orca\workspaces\ProjectA\develop`.
- Windows PowerShell 환경. 실행 파일은 아래 Godot 경로를 그대로 사용한다. 새 엔진 설치/이름 변경/PATH 검색은 하지 않는다.
- 기본 실행: `project.godot` → `scenes/main/main.tscn` → `MartGraybox`. Main Inspector의 `start_in_prototype=false`가 기본이다.
- 물리 전용 룸: `scenes/test/prototype_test_room.tscn`을 F6로 실행하거나 Main에 `-- --prototype` 인수를 전달한다. 기본 F5 마트에 A~E 테스트 큐브/피해 더미가 모두 있는 것은 아니다.
- 첫 확인: F5 → 5초 뒤 배송 → 상품을 같은 색 Shelf에 진열 → 일반 손님 계산 → K로 취객 생성 → Carry/카트로 출구 제거. 기존 시스템을 다시 만들지 않는다.
- 다음 수정 전에는 해당 책임 파일과 상속받는 테스트를 확인한다. 특히 `prompt5_smoke.gd`는 Prompt 4 헬퍼, Prompt 4는 Prompt 1 헬퍼를 재사용한다. 공통 테스트 헬퍼를 바꾸면 다른 단계에도 영향을 준다.
- 인수인계 시 Git에는 README 수정과 `.gitignore`, `PROJECT_NOTES.md`, `project.godot`, `scenes/`, `scripts/`, `tests/`의 untracked 상태가 남아 있다. 구현물이 모두 커밋되었다고 가정하지 않는다. `git clean`, reset 또는 프로젝트 재생성으로 지우지 않는다. 이 작업에서 커밋하지 않았다.
- `.gitignore`는 `.godot/`, `*.tmp`를 제외한다. `.godot` 안의 로그·스크린샷은 로컬 증거이며 다른 체크아웃에는 없을 수 있다. 없으면 테스트를 다시 실행한다. 스크립트의 `.gd.uid`는 Godot가 생성한 식별 파일이다.
- 이 환경에서 `rg`는 사용 불가했던 이력이 있어 PowerShell `Get-ChildItem`/`Select-String`을 사용했다. 한글 문서는 `Get-Content -Encoding UTF8`로 읽는다. Godot 텍스트 씬은 UTF-8 BOM 때문에 `Expected '['` 임포트 오류가 났던 이력이 있으므로 UTF-8 **BOM 없이** 저장한다.
- Git 소유권 경고가 나면 명령별 `git -c safe.directory=C:/Users/user/orca/workspaces/ProjectA/develop ...`를 사용했던 환경이다. 전역 설정 변경이나 파일 소유권 변경은 하지 않았다.

### 2. 구현 단계 요약

| 단계 | 현재 유지되는 결과 |
| --- | --- |
| Prompt 0 | Godot 기반, Main/테스트 룸, 1인칭 WASD·마우스·중력·점프·충돌·Esc, Action 입력 |
| Prompt 1 | 공통 물리 상품 Grab/Carry/Drop/Throw, price/weight, 충돌 피해·넉백, A~E 및 테스트 타깃 |
| Prompt 1.1 | 우클릭 Press/Hold/Release Charge Throw, 작은 게이지, 무게·가격·충전량 결합 |
| Prompt 2 | 실제 카트, 물리 적재·탑승·밀기/당기기·Charge Launch·Cart Bomb·경사로·전도 |
| Prompt 2.1 | 이동 의도 직접 전달, 보유 카트 충돌 예외, 비상 거리, 플레이어의 RigidBody 밀기 |
| Prompt 3 | Mart Graybox, 배송 트럭/팔레트, 3종 물리 상품, 올바른 진열/품절/재Grab 기반 |
| Prompt 3.1 | 빠른 카트 조향·가속, 완만한 적재 패널티, Loading/Backroom→넓은 후면문→Store 직선 동선 |
| Prompt 4 | 일반 손님, FIFO Queue, 아이콘 구매 목록, Scan/Payment, Patience, Sales/Unpaid Loss |
| Prompt 5 | 취객, 공통 Character Carry/Drop, 상품 흔들림/파손, 카트 운반, 외부 제거와 통계 |

최종 목표는 2~4인 협동이지만 **현재 실행은 로컬 1인 프로토타입**이다. 네트워크, 역할 배정, 실제 라운드 및 저장 기능은 없다. 현재 금전 수치는 개별 시스템의 세션 누적값이며 통합 자금/Profit이 아니다.

### 3. 파일 지도와 변경 이력

경로는 프로젝트 루트 기준이다. 책임을 찾을 때 이 표부터 확인한다.

| 파일/경로 | 책임 및 현재 상태 |
| --- | --- |
| `project.godot` | 실행 씬·렌더러·Input Map. Prompt 5에서 `debug_spawn_drunk`(K) 추가 |
| `scripts/main.gd`, `scenes/main/main.tscn` | Mart/Prototype 선택·인스턴스 생성 |
| `scripts/player/player_controller.gd`, `scenes/player/player.tscn` | CharacterBody 플레이어·카메라·중력·몸 밀기. Prompt 5에서 캐릭터 운반 속도 배율과 보유 대상 중복 밀기 예외 추가 |
| `scripts/interaction/player_interaction.gd` | ray 후보 선택·한 대상 소유·Grab/Drop·Charge/UI·목표 sweep. Prompt 5에서 CarryableCharacter 판별/투척 금지 추가 |
| `scripts/interaction/grabbable_body.gd` | RigidBody 상품 데이터·운반·첫 충돌 피해. Prompt 5에서 변경하지 않음 |
| `scenes/interactables/test_object.tscn` | 테스트 큐브 공통 씬. A~E 인스턴스 데이터는 Prototype 룸에서 지정 |
| `scenes/interactables/products/can.tscn`, `watermelon.tscn`, `appliance.tscn` | 실제 업무용 3종 상품 형태·price·weight·product_type |
| `scripts/interaction/shopping_cart.gd`, `scenes/interactables/shopping_cart.tscn` | 카트 물리·손잡이·제어·적재·발사·충돌. Prompt 5에서 게임 로직/씬 변경하지 않음 |
| `scripts/interaction/test_damage_target.gd`, `scenes/test/test_damage_target.tscn` | HP·넉백·로그를 가진 물리 검증 더미. 실제 적/보스 시스템이 아님 |
| `scenes/test/prototype_test_room.tscn`, `scenes/test/cart_test_zone.tscn` | 기존 물리 테스트 공간·A~E·카트·타깃·경사로 유지 |
| `scripts/systems/graybox.gd` | primitive 박스/표지 생성 공통 도우미 |
| `scripts/systems/mart_graybox.gd`, `scenes/mart/mart_graybox.tscn` | 마트 정적 공간과 Player/Cart/Shelves/Delivery/Customers 배치. Prompt 5에서 Drunks 노드·실제 전면 출입구·외부 바닥 추가, 문 표시는 바닥 띠로 변경 |
| `scripts/systems/delivery_manager.gd` | 배송 시간·트럭·팔레트·실물 생성·하역/잔류 판정 |
| `scripts/systems/stock_shelf.gd`, `scenes/interactables/stock_shelf.tscn` | StockZone·안정화 대기·정상 재고·현재 상태 재검증 |
| `scripts/systems/basic_customer.gd`, `scenes/interactables/basic_customer.tscn` | 일반 손님 CharacterBody의 매장 방문·대기·표정·퇴장·카트 반응 |
| `scripts/systems/customer_manager.gd` | 일반 생성 주기·구매 참조 예약·Queue·판매/미결제 거래·제거 |
| `scripts/systems/checkout.gd`, `scenes/interactables/checkout.tscn` | 실제 SCAN/PAY 버튼·ray/E·상품별 스캔 진행·간단한 UI |
| `scripts/systems/purchase_icons.gd` | 외부 에셋 없이 상품별 모양/색상과 스캔 체크 표시 |
| **`scripts/interaction/carryable_character.gd`** | **Prompt 5 신규:** 공통 물리 캐릭터 Carry/Drop, 운반자 충돌 예외, 접지/카트 지지 판정 |
| **`scripts/systems/drunk_customer.gd`**, **`scenes/interactables/drunk_customer.tscn`** | **Prompt 5 신규:** 취객 고유 배회·흔들림·상품 방해/파손, 보라색 캡슐/표정 |
| **`scripts/systems/drunk_test_manager.gd`** | **Prompt 5 신규:** K 생성 제한·외부 제거 구역·drunks_removed/broken_product_value·간단한 표시 |
| **`tests/prompt5_smoke.gd`** | **Prompt 5 신규:** 실제 입력/물리 Carry·Drop·벽·투척 차단·파손·카트 운반/제거·계산 병행 |
| `tests/prompt0_smoke.gd` ～ `tests/prompt4_smoke.gd` | 기존 단계 회귀. Prompt 5에서 `prompt2_smoke.gd`의 Cart Bomb 수신 타깃만 stationary로 변경; 차체 넉백 검사는 유지 |
| `README.md` | 실행·현재 키 조작·수동 시나리오·검사 실행 안내. Prompt 5 조작 반영 |
| `PROJECT_NOTES.md` | 이 인수인계와 설계·기본값·검증 기록. 이번 문서 정리 요청에서 수정한 유일한 파일 |

### 4. 시스템 연결부 — 다음 변경 시 지킬 계약

- `Player/Interaction.held_object`는 `RigidBody3D` 하나다. `GrabbableBody`, `ShoppingCart`, `CarryableCharacter`가 `holder`, `begin_carry(controller, player)`, `end_carry()`를 공유한다. 일반 손님은 CharacterBody3D라 이 후보에 들어가지 않는다.
- 상품과 캐릭터는 `carry_radius`/`hold_target`을 사용하고, 카트는 `update_control()`로 분기한다. 상품 Carry 튜닝과 캐릭터 Carry 튜닝은 별도 변수다. 새 캐릭터는 자신 크기에 맞는 충돌체와 carry_radius가 필요하다.
- CharacterCarry는 입력 단계와 `throw_held()` 내부 모두에서 Charge/Throw를 거부한다. 대상만 추가하면서 실수로 상품 `price/weight/launch()` 경로에 보내지 않는다. 한 플레이어가 상품+캐릭터를 동시에 들 수 없다.
- `CarryableCharacter._integrate_forces()`가 보유 중 추종/자유 상태 `_free_motion()`을 나눈다. `_physics_process()`는 Drop 후 충돌 복구를 맡는다. 파생 캐릭터가 `_ready()`/`_physics_process()`를 override하면 필요한 `super` 호출을 유지한다. `_exit_tree()` 충돌 정리도 보존한다.
- Character Drop은 중력 복구와 잔여 속도 최대 2m/s 제한을 적용한다. 운반자 충돌은 수평 간격 >0.8m 또는 수직 간격 >1.8m로 분리된 후 복구한다. 카트 Drop의 즉시 충돌 복구 방식과 혼동하지 않는다.
- 상품 진열의 권위는 `StockShelf`다. 구매나 취객 로직에서 stock_count를 직접 증감하지 않는다. `stocked_objects`와 `has_stock()`로 실제 물체/현재 위치/보유/삭제 상태를 확인한다.
- `CustomerManager._claims`는 같은 물체의 중복 구매 배정 방지용이며 플레이어 상호작용 잠금이 아니다. 재고가 이동/파손되면 기존 요청을 다른 물체로 자동 대체하지 않고 품절 종료한다. 판매와 미결제 모두 `finish()`가 유효 물체 전부를 검증한 뒤 한 번만 제거/집계한다.
- 일반 손님 `sales`/`unpaid_loss`는 `Customers`, 취객 `drunks_removed`/`broken_product_value`는 `Drunks` 노드 소유다. Delivery의 Delivered/Unloaded/Left Behind는 별도 로그/last_result다. 세션 종료 시 모두 초기화된다.
- 취객 `product_broken(value)` 신호는 테스트 매니저의 `_record_breakage()`에 연결된다. 독립적으로 취객 씬을 배치하면 이 신호를 연결해야 금전 누적도 된다. Broken Products는 모든 충돌의 공통 파손 시스템이 아니라 현재 취객 파손만 기록한다.
- 카트 `cargo`는 `Array[GrabbableBody]`다. NPC를 강제로 append하면 라벨/price/투척 피해 코드와 충돌한다. 캐릭터는 실제 6kg 바디로 접촉하지만 effective_mass 및 상품 Load UI 합계에는 포함되지 않는 현재 한계를 유지/명시한다.
- 고객 동선·Drunk 목표·생성·외부 제거에는 현재 마트 좌표가 하드코딩되어 있다. Drunks/Customers는 원점 배치 기준이다. 마트 레이아웃이나 노드 위치를 바꾸면 여러 좌표와 테스트를 함께 검토해야 한다.
- 일반 손님은 Entrance **안쪽**의 기존 exit_position(-3,0.01,10.8)에 도착하면 제거된다. 취객 제거는 문 **밖** 별도 Area다. 일반 손님을 취객 제거 카운트에 넣지 않는다.

### 5. 현재 조작과 작업 동선

| 입력 | 동작 |
| --- | --- |
| WASD / 마우스 / Space | 이동 / 시점 / 점프 |
| 좌클릭 (`grab`) | 바라보는 상품·카트 손잡이·취객 잡기 / 보유 대상 놓기 |
| 우클릭 (`throw`) | 상품·카트만 누르기 시작→충전→Release 투척/발사. 취객에는 효과 없음 |
| E (`interact`) | 계산대 안쪽에서 SCAN/PAY를 바라보고 처리 |
| K (`debug_spawn_drunk`) | 마트 입구에 테스트 취객 생성. 자동 이벤트 확률은 없음 |
| Esc | 마우스 잠금 해제/복귀; 충전 취소 |
| F8 → F5 | Godot 에디터에서 실행 종료/새 세션 시작. 게임 자체 리셋 키가 아님 |

후면 배송/Backroom → 폭 5m 중앙문 → Store의 기본 배송 경로는 직선이다. 전면 왼쪽 Entrance는 폭 4m 출입구, 계산대는 전면 오른쪽 (5,0,10), 조작자는 +Z 쪽에 선다. 진열하지 않은 초기에는 정상 구매 재고가 없으므로 일반 손님이 품절 퇴장하는 것이 정상이다.

### 6. 실행·회귀 검사 재현 명령

프로젝트 루트 PowerShell에서 실행한다. Godot 실행은 현재 도구 환경의 권한 정책에 따라 승인 실행이 필요할 수 있다. 다음 스크립트의 실행 파일 경로를 바꾸지 않는다.

```powershell
$martGodot = 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
& $martGodot --headless --version
& $martGodot --headless --path . --editor --import --quit 2>&1 | Tee-Object -FilePath .godot/check_import.log | Out-String
& $martGodot --path .
# 별도 물리 테스트 룸:
# & $martGodot --path . -- --prototype
```

자동 검사는 게임/에디터의 다른 실행을 종료한 후 **창 모드, 순차 실행**한다. 여러 Godot 테스트 창을 동시에 띄우거나 검사 중 마우스/키보드/Alt+Tab을 조작하면 포커스·입력 결과가 달라질 수 있다. 전체 검사는 수 분 이상 걸릴 수 있으며 모든 검사가 20초 안에 끝나는 것은 아니다.

```powershell
$martGodot = 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
$martSuites = @('0','1','1_1','2','2_1','3','3_1','4','5')
foreach ($suite in $martSuites) {
    & $martGodot --path . --script "res://tests/prompt${suite}_smoke.gd" 2>&1 |
        Tee-Object -FilePath ".godot/check_prompt${suite}.log" | Out-String
    Write-Output "Prompt $suite exit=$LASTEXITCODE"
}
# Main: 실제 120초 대기가 아니라 고정 프레임 시간으로 120초 시뮬레이션.
& $martGodot --headless --path . --fixed-fps 60 --quit-after 7200 2>&1 |
    Tee-Object -FilePath .godot/check_main.log | Out-String
Get-ChildItem .godot/check_*.log | Select-String -Pattern 'SCRIPT ERROR|ERROR:|FAIL:'
```

GUI exe 출력을 파이프로 받아 실행 완료를 기다리는 방식이다. 헤드리스는 임포트/Main 로딩·시간 흐름 확인에만 사용한다. 입력 검사에 `--headless`를 붙이지 않는다. `error_after_0.5s`는 정상 측정 로그이므로 단순히 `error`라는 단어만 검색해 실패로 오인하지 않는다.

| 검사 스크립트 | 최근 최종 PASS | 핵심 검사 |
| --- | ---: | --- |
| `tests/prompt0_smoke.gd` | 22 | 입력·이동·점프·카메라·바닥/벽·마우스 잠금 |
| `tests/prompt1_smoke.gd` | 48 | 생성/데이터·거리·Grab/Drop·Carry·실제 투척·가격/중량 피해 |
| `tests/prompt1_1_smoke.gd` | 40 | 충전/Release·취소·UI·비행·피해/넉백 |
| `tests/prompt2_smoke.gd` | 41 | 카트·실제 적재·Launch·피해/넉백·Cart Bomb·탑승·전도/복원 |
| `tests/prompt2_1_smoke.gd` | 28 | 직접 구동·충돌 예외·거리·몸 밀기·기존 Launch |
| `tests/prompt3_smoke.gd` | 32 | 배송·실물·하역/잔류·진열/제거/오진열/초과 진열 |
| `tests/prompt3_1_smoke.gd` | 29 | 빠른 카트·적재 패널티·직선 후면 동선 |
| `tests/prompt4_smoke.gd` | 54 | 고객·재고 예약·Queue·Scan/Pay·품절·손실·6명 스트레스 |
| `tests/prompt5_smoke.gd` | 33 | 취객·Carry/Drop·벽·파손·직접/카트 제거·계산 병행 |
| **총계** | **327** | 최종 로그의 SCRIPT ERROR / ERROR / FAIL = 0 |

증거: `.godot/final5_prompt*.log`, `final5_import.log`, `final5_main.log`, `final5_preview.log`. 시각 확인: `.godot/p5_drunk.png`, `.godot/p5_checkout.png`. `.godot/p5_preview.gd`는 로컬 화면 확인 도우미일 뿐 정식 게임/회귀 테스트 진입점이 아니다.

### 7. 남은 문제와 의도된 제한

| 항목 | 관찰/현재 처리 | 다음 세션의 주의점 |
| --- | --- | --- |
| 카트 밀착 반복 피해 | 사용자 지시로 보존 | 전투 시스템 완성 후 재검토. 지금 임의로 쿨다운/피해 규칙을 수정하지 않는다 |
| 물리 검사 변동 | Prompt 3.1 가속/제동 최초 실패→동일 코드 재실행 통과 | 원인 확정 아님. 실패 로그를 보존하고 초기 적재 상태·입력·접촉을 조사한다. 성공할 때까지 무조건 반복하지 않는다 |
| Cart Bomb 검사 범위 | 움직이는 더미의 상품 명중 두 번 실패; 검사 수신 타깃만 넉백 OFF로 분리 | 차체 넉백은 같은 파일의 별도 실제 충돌 검사로 유지. 고정 수신기 통과가 모든 이동 타깃 명중을 보장하지 않음 |
| NPC 길찾기 | 일반 손님 고정 waypoint, 취객 랜덤 목표 | 상품/카트로 막으면 정체 가능. 내비게이션/막힘 복구는 미구현 |
| 생성 입구 혼잡 | 취객은 물리 겹침 검사, 일반 손님 생성은 기존 일반 손님 간 근접 확인 | 모든 장애물에 대한 공통 생성 회피가 구현된 것으로 간주하지 않는다 |
| Carry/적재 안정성 | 좁은 곳 안전 해제, 과적·급회전·뒤집힘 때 이탈 가능 | Carry 반지름/형상을 함께 튜닝. 캐릭터는 upright 캡슐이며 ragdoll이 아님 |
| 캐릭터 카트 중량 | 바디 질량만 실제 접촉에 작용, 상품 합계에서 제외 | NPC 중량을 cargo 배열에 바로 넣지 않는다. 별도 요구가 생기면 기존 상품 인터페이스와 분리 검토 |
| 외부 공간 | 제거용 작은 바닥만 있음 | 완성된 외부 맵/추락 복구 시스템이 아님 |
| 시각/손맛 | 캡슐·primitive·디버그 라벨, 복잡한 적재 시 겹칠 수 있음 | 장시간 수동 안정성·2~4초 계산 체감은 추가 확인 대상 |
| 금전/파손 | 개별 세션 카운터, 취객 강한 접촉 상품 제거 | 통합 회계·모든 원인의 파손·저장·최종 정산 미구현 |

수동 확인 우선순위: **실제 플레이어 Carry 벽 접근 → 카트 안 Drop/저속 운반/출구 Launch → 계산 도중 취객 처리 후 복귀 → 상품 파손 시 Stock/예약 고객의 품절 처리 → 빈/적재 카트 기존 조작감**. 테스트마다 F8→F5로 초기 조건을 복원한다. K가 반응하지 않으면 마우스 잠금, 생성 enable, 활성 2명 제한, 입구 장애물부터 확인한다.

### 8. 다음 작업: Lost Child 준비와 작업 경계

아래는 다음 기능 요청을 받았을 때의 확장 제안이다. 이번 문서 정리로 Lost Child 구현을 시작하거나 세부 규칙을 확정하지 않는다.

1. 사용자 수동 테스트에서 Prompt 5 문제가 보고되면 먼저 재현하고 영향 범위만 수정한다. 특히 Carry/카트 동작은 이후 특수 손님의 공통 기반이다.
2. Lost Child가 요청되면 `CarryableCharacter`를 상속하는 별도 NPC를 만들 수 있다. 취객의 배회/상품 파손 로직을 복사하거나 일반 Checkout Queue에 넣지 않는다.
3. `holder`가 있으면 자율 행동을 멈추고, Drop하면 요구된 미아 행동을 재개하도록 구현한다. 몸 크기·질량·carry_radius·시각 표현을 함께 정한다. 기존 좌클릭과 한 대상 소유 구조를 재사용한다.
4. 부모 위치/식별 방식·올바른 인계 조건·손에 든 상태와 카트 운반 허용 여부·재Grab·성공 카운터는 **아직 미정**이다. 다음 사용자 프롬프트를 기준으로 결정한다.
5. 현재 `Drunks/ExitRemovalZone`은 `DrunkCustomer`만 받도록 되어 있다. 미아를 밖에 버리면 성공하도록 일반화하지 않는다. 부모 인계 판정은 별도 책임으로 추가한다.
6. 새 기능 검사는 생성·고유 행동·Carry/Drop·잘못된 인계 거부·성공 한 번 집계·카트 운반(요구 시)·일반 손님/취객 동시 동작을 포함하는 방향으로 준비한다. 기존 Prompt 0~5 검사는 유지한다.
7. 완료 후 이 문서의 현재 단계/기본값/변경 파일/최종 테스트 수/남은 문제와 README 조작법을 함께 갱신한다.

아직 구현하지 않을 것: Character Throw, 플레이어/일반 손님 Carry, 다른 특수 손님, 관광버스, 물/화재, Cart Rocket/소화기, 무기·보스, 복권, Round Director, 통합 정산, 세이브, 멀티플레이. 향후 기획은 아래 참고 목록이며 즉시 구현 지시가 아니다.

---

## 상세 구현 참고와 단계별 기록

## 이 환경의 Godot 실행 경로
- ZIP을 압축 해제한 Godot를 사용한다. `godot` 명령/PATH 검색, 파일명 변경, 다른 버전 설치를 하지 않는다.
- `D:\Godot_v4.7.2-stable_win64.exe`는 폴더다. 실제 실행 파일의 절대 경로는 `D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`다.
- 확인한 버전: `4.7.2.stable.official.ed1daf0bf`.
- PowerShell 버전 확인: `& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --headless --version`
- 자동 검증: 같은 실행 파일에 `--path . --script res://tests/prompt0_smoke.gd`를 전달한다. 프로젝트 루트에서 실행한다. 마우스 잠금이 필요한 테스트이므로 창 모드로 실행하며 검사 완료까지 입력하지 않는다. 헤드리스 모드는 마우스 잠금을 지원하지 않으므로 임포트/씬 로딩 검사에만 사용한다.

## 한 줄 설명 / Core Gameplay
단순한 야간 마트 업무가 물리 장난과 예상하지 못한 사건으로 뒤엉키는 2~4인 3D 협동 코미디 게임.

- 기본 업무는 정확히 **입고·진열·계산**이다. 고정 직업 없이 모든 플레이어가 모든 업무를 수행한다.
- 복잡한 경영 시뮬레이션보다 단순한 규칙에서 생기는 즉흥적인 협동 상황을 우선한다.
- Toy-like Interaction: 원래 용도·장난 용도·위기 상황의 용도를 검토하되 세 용도를 억지로 강제하지 않는다.
- 주요 물건은 실제 물리 오브젝트다. 보기 → 집기 → 옮기기 → 내려놓기/던지기가 기본이며 가상 인벤토리로 대체하지 않는다.
- `price`는 가치와 기본 투척 피해에, `weight`는 운반 느낌·거리·충격량·향후 카트 중량에 관여한다. 비싼 상품 파손은 향후 정산 손실이다. 현재 공식은 프로토타입용이며 최종 밸런스는 미정이다.
- 계산 손님은 실물 상품 대신 아이콘/말풍선/계산서로 구매 목록을 표현한다. 바코드 스캔·결제로 처리하며 오래 기다리면 상품을 가지고 도주하여 손실을 낸다.
- NPC는 긴 대사 대신 애니메이션·아이콘·이모티콘·효과로 상태를 표현한다.

## 현재 단계: Prompt 5 완료 — 취객 + Character Carry

- `CarryableCharacter`는 RigidBody3D 기반 공통 운반 바디다. 회전 잠금 캡슐이며 ragdoll이 아니다. 좌클릭 Grab/Drop, 한 번에 대상 하나, 우클릭 Charge/Throw는 입력과 직접 호출 모두 차단한다. 상품·카트 로직은 별도 타입으로 유지한다.
- 들고 있을 때 중력을 잠시 끄고 제한된 속도/가속으로 기존 충돌 sweep의 목표를 따라간다. 벽/바닥/다른 물체 충돌은 유지한다. 운반자와만 양방향 충돌 예외를 설정하고 Drop 뒤 겹침이 해소되면 복구한다. 취객 제거 시 held 참조도 해제한다.
- 기본 Carry 값: carry_radius=0.82m, carry_follow_strength=10, carry_speed=7m/s, carry_acceleration=35m/s², carrier_speed_multiplier=0.85. 플레이어 기본 5m/s → 취객 운반 시 4.25m/s. 별도 인벤토리, 손 IK, Character Throw는 없다.
- `DrunkCustomer`는 일반 손님/Checkout Queue와 독립이다. 매장 안 목표를 2초마다 고르고 흔들리는 방향으로 걷는다. 보라색 캡슐과 `~_~`/`@_@` 표정, 몸통 기울기로 표현한다. 시간 경과에 따른 자동 퇴장은 없다. 기본 wander_speed=1.8, wander_acceleration=14. 보행 힘이 바닥 마찰을 이기도록 했으며 보행 중 sleeping은 사용하지 않는다.
- 취객은 실제 바디 접촉으로 상품을 밀고, Shelf 충돌 시 가까운 실제 상품에 작은 impulse를 준다. 별도 Stock Count 처리는 없으며 기존 Shelf 판정을 그대로 사용한다. product_push_impulse=2.5, contact_cooldown=1초. 질량이 작은 상품이 같은 impulse에서 더 크게 움직인다.
- 충돌 직전 수평 속도가 break_min_speed=2.7m/s 이상이면 접촉 상품을 한 번만 파손/제거하고 실제 price를 `broken_product_value`에 더한다. 평상시 보행은 이 임계값보다 느리다. 들고 있거나 이미 판매/파손 처리한 상품은 제외한다. 전체 정산·파편 시스템은 없다.
- 카트 위 Drop 후 바닥 접촉 대상이 ShoppingCart이면 자율 보행만 중단한다. 좌석/부모 연결/위치 고정/속도 복사는 없다. 실제 바구니 충돌로 함께 이동하며 바닥으로 내려오면 보행한다. 상품 전용 카트 cargo/무게 계산에는 NPC를 넣지 않았다. NPC 실제 6kg 질량은 물리 접촉에 작용한다.
- Entrance의 기존 벽 표시를 실제 폭 4m 출입구로 열고 작은 외부 바닥을 추가했다. `Drunks/ExitRemovalZone`은 중심 (-3,1.5,14), 크기 (4,3,2)다. 취객이 어떤 방식으로 들어오든 한 번만 drunks_removed 증가/Despawn. 들고 진입해도 즉시 인정한다. 일반 손님은 해당 제거 대상이 아니다.
- 테스트 생성: Input Map `debug_spawn_drunk` = K. Mart의 `Drunks` Inspector enable_drunk_test_spawn=true, max_test_drunks=2. 자동 확률/타이머/Director는 없다. 입구가 막혀 있거나 두 명이 남아 있으면 생성을 건너뛴다. 일반 손님 생성기는 변경하지 않았다.
- 수동: F5 → K → 진열 상품과 취객 충돌 관찰 → 좌클릭 Carry/WASD/우클릭 차단/Drop → 출입구 밖 운반 → 다시 K → 카트 위 Drop → 밀기 또는 Charge Launch로 외부 제거. 일반 손님 Scan/Payment와 배송은 계속 작동한다.
- 알려진 제한: 보행은 단순 랜덤 목표여서 장애물 우회/복구 AI가 없다. 좁은 곳에서는 기존 Carry 안전 해제가 작동할 수 있다. 캐릭터는 항상 선 캡슐이며 카트가 뒤집히거나 과적하면 이탈할 수 있다. 카트 위에서 아주 짧게 공중에 뜨는 동안에는 보행하지 않는다. 외부 바닥은 작은 테스트 구역이다.
- 기존 카트 접촉 반복 피해는 수정하지 않았다. 특수 손님 중 취객만 구현했다. Lost Child/Character Throw/멀티플레이/전체 정산은 미구현이다. 다음 단계는 공통 Carry 바디를 재사용하는 Lost Child이며, 부모 찾기·인계 판정은 아직 없다.

### Prompt 5 최종 검증

- Godot 4.7.2: Prompt 0 / 1 / 1.1 / 2 / 2.1 / 3 / 3.1 / 4 / 5 = 22 / 48 / 40 / 41 / 28 / 32 / 29 / 54 / 33개, 총 327개 통과. 최종 9개 검사·임포트·Main·화면 확인 로그 오류 0건. `.godot/final5_*.log`.
- Main은 fixed-fps 60, 7,200프레임(시뮬레이션 120초)으로 배송 도착/출발까지 실행했다. 실제 창 입력으로 취객 Carry/Drop/벽 충돌/투척 차단/이동 패널티를 확인했고 `.godot/p5_drunk.png`에서 보라색 캐릭터·표정·열린 출입구·간단한 카운터를 확인했다.
- 신규 검사: 직접 Carry 제거 1명 + 실제 카트 발사 제거 1명 = drunks_removed 2. 물리 카트 운반 시 약 0.80m 이동. Shelf 접촉 상품 약 0.62m 이동. 강한 충돌 파손 금액 $500 한 번 기록. 취객이 있는 동안 일반 손님 판매 $5 성공. 물리 산포 수치는 실행별로 달라질 수 있다.
- 첫 회귀에서 Prompt 3.1 적재 가속/제동 검사가 실패했으나 같은 코드 재실행에서 29개 통과했다. Cart Bomb의 움직이는 타깃에 대한 개별 상품 명중은 두 번 실패했다. Prompt 2 검사 안에서만 해당 타깃의 넉백을 끄고, 앞의 별도 실제 차체 피해/넉백 검사는 그대로 유지해 원인을 분리했다. 게임 씬/카트 로직은 변경하지 않았다. 최종 Cart Bomb은 적재 5개, 이탈 2개, 차체 1회/상품 1회 타격. 초기 실패 로그 `.godot/p5_first_*`, `.godot/p5_second_prompt2.log`를 보존했다.
- 현재 물리 검사는 모든 실행의 결정성을 보장하지 않는다. 자동 검사는 통과했지만 복잡한 과적·막힌 동선·사용자 조작감은 수동 확인이 필요하다.
### Prompt 4에서 유지한 기반 — 일반 손님 + 계산

- `Customers` 노드의 CustomerManager가 Entrance 안쪽에서 일반 손님을 생성한다. 기본 6~10초 간격, 활성 최대 6명이며 입구가 막히면 이번 생성을 건너뛴다. 별도 라운드/난이도 시스템은 없다.
- 상태는 STORE → QUEUE → CHECKOUT → EXIT. STORE는 왼쪽 통로의 짧은 waypoint 방문이며 왕복 경로를 분리해 손님끼리 마주 서는 교착을 방지한다. 재고가 없거나 구매 대상이 옮겨졌으면 DISAPPOINTED(2초, X/슬픈 표정) → EXIT. 대기 중 시간 만료는 미결제 EXIT([!])다. 퇴장 위치까지 실제로 걸은 뒤 제거한다.
- 손님은 CharacterBody3D 캡슐과 색상 상품 모양 아이콘만 가진다. 상품 Grab/운반, 피해/사망/체력/ragdoll/Character Carry는 없다. 가벼운 걷기 bob과 표정 색상으로 상태를 나타낸다.
- 구매 목록은 정상 진열 상품 중 1~3개를 고른다. 같은 상품 중복 수량은 개별 아이콘으로 표시한다. 재고가 전혀 없으면 3종 중 한 종류를 원하지만 품절 퇴장한다. 테스트의 `spawn_customer([상품 종류...])`로 특정 품목 부족도 검증할 수 있다.
- 구매 예약은 실제 진열 물체 참조를 중복 배정하지 않는 용도다. 상품을 고정/숨김/이동하지 않고 플레이어의 Grab/Throw를 허용한다. 유효 재고가 없는 예약을 다른 상품으로 자동 치환하지 않는다. 결제 직전 모든 대상의 현재 위치·소유·진열 상태를 다시 검사한다.
- `StockShelf.has_stock`은 오래된 count만 믿지 않고 현재 상품 상태를 검사한다. 거래는 중간 대기 없는 전체 성공/전체 취소 방식이다. 성공 시 실제 `product.price` 합계만 기록하고 해당 상품을 제거한다. 중복 결제·중복 손실은 resolved 상태로 차단한다.
- 대기열은 진입 순서 FIFO, 기본 1.25m 간격. 계산 위치에 실제 도착한 맨 앞 손님만 계산 가능하다. 앞 손님이 떠나면 다음 손님이 앞으로 이동한다. NPC 간 근거리 분리 보조와 실제 충돌을 사용한다.
- 계산 위치는 기존 매장 전면 우측 (5,0,10). 안쪽(+Z, 계산대 뒤)에서 파란 SCAN을 보고 E → 상품 한 개, 최소 0.5초 간격. 모두 스캔하고 마지막 처리 시간이 지나면 초록 PAY를 보고 E. UI 아이콘의 체크와 진행 수량을 표시한다. 마우스/이동/기존 물리 입력을 잠그지 않으며 자리를 떠나도 해당 손님의 진행은 유지한다.
- Patience 기본 25초는 Queue에 등록될 때부터 감소한다. 남은 비율 >60%는 :), >30%는 노란 :|, 이하 주황 :!이다. 판매 전에 상품이 없어지면 품절로 종료해 허위 손실을 만들지 않는다.
- 미결제 탈출은 유효한 구매 상품을 Shelf에서 제거하고 `unpaid_loss += 실제 상품 가격 합`을 한 번 기록한다. NPC가 실제 물체를 들지는 않는다. 품절 퇴장은 매출/손실 모두 0이다. `sales`와 `unpaid_loss`는 세션 합계와 Output 로그만 제공하며 최종 정산/세이브는 없다.
- 카트 접촉은 손님의 근접 물리 감지에서 카트의 접근 속도를 받아 최대 3.5m/s 반응, 초당 6m/s 감쇠로 처리한다. NPC에는 receive_impact 피해 핸들러를 만들지 않았다. 기존 카트 접촉 반복 피해 로직은 수정하지 않았다.
- Inspector: Customers의 spawn_interval_min=6, spawn_interval_max=10, max_active_customers=6, patience_time=25, queue_spacing=1.25, max_purchase_units=3, spawning_enabled=true. Customer 씬 move_speed=2.2, disappointment_time=2, max_push_speed=3.5, push_decay=6. Checkout 씬 interact_distance=2.8, scan_interval=0.5.
- 수동: 상품 진열 → 입장/매장 방문/대기 관찰 → 계산대 뒤 SCAN E 반복 → 초록 PAY E → 매출·진열 수 감소 확인. 손님을 방치해 표정/손실을 확인하고, 예약 상품을 직접 집어 품절 취소를 확인한다. Spawn Interval을 줄여 Queue 압박을 확인한다. 계산 도중 이동/Grab/Cart 후 복귀 가능하다.
- 제한: 고정 waypoint 기반이며 임의로 쌓은 상품/카트에 대한 전역 우회 경로 탐색은 없다. 통로를 완전히 막으면 손님이 막힐 수 있다. 최소형 캡슐/아이콘 UI이고 손맛 2~4초 목표는 수동 확인 대상이다. Scanner 장난 BEEP, 취객 외 특수 손님, 관광버스는 미구현이다.
- Prompt 5에서 일반 손님 기반을 유지하면서 별도 취객/Character Carry를 추가했다. 다음은 Lost Child다.


### Prompt 4 최종 검증

- Godot 4.7.2: Prompt 0 22개 / 1 48개 / 1.1 40개 / 2 41개 / 2.1 28개 / 3 32개 / 3.1 29개 / 4 54개, 총 294개 통과. 최종 임포트·8개 검사·Main 로그에 오류 없음. 로그: `.godot/final4_*.log`.
- Main은 fixed-fps 60으로 7,200프레임(시뮬레이션 120초) 실행해 첫 배송 도착/출발까지 확인했다. 별도 창 모드 검사에서 실제 E 입력/버튼 ray, 상품 판매, 손님 이동/퇴장, 계산 UI 화면을 확인했다.
- 실측: Can+Watermelon 결제 매출 $55, 미결제 Can 손실 $5. 각각 실제 상품 제거 및 중복 거래 차단 확인. 6명 모두 대기열에 도착했고 최소 중심 간격 약 1.25m였다.
- Prompt 3의 물리 Grab 관련 검사는 첫 실행에서 실패했으나 코드 변경 없이 재실행해 32개 통과했다. 입력/물리 결과 변동 가능성이 있어 최종 통과가 모든 실행의 결정성을 보장하지는 않는다.
- 계산 2~4초의 체감, 상품/카트로 통로를 막았을 때의 동작은 아래 수동 절차로 추가 확인한다. 카트의 기존 접촉 반복 피해는 변경하지 않았다.

### Prompt 3.1에서 유지한 기반

- 최종 회귀: Prompt 0/1/1.1/2/2.1/3/3.1 = 22/48/40/41/28/32/29개, 총 240개 통과. 최종 임포트·Main(첫 배송 6개)·검사 로그 오류 0건. `.godot/final31_*.log`를 참고한다. 중간 상품 충전 검사는 포커스 영향 의심 실패 후 창 작업 없이 재실행하여 40개 모두 통과했다.
- 새 조작감 실측(빈/16kg 적재): 0.3초 속도 5.08/5.21m/s, 90도 전환 0.5초 뒤 방향 오차 4.86/6.17도, 연속 회전 후 정지 입력 1초 뒤 잔여 속도 0.11/0.43m/s. 물리 접촉에 따른 예시 수치이며 적재가 더 빠르다는 의미는 아니다. Full Launch는 17.90/11.17m/s로 유지됐다. Cart Bomb은 차체 1회·상품 1회 피해와 5개 이탈을 확인했다.
- 방향: 실제 카트의 노동감보다 빠른 업무 전환을 우선한다. 일반 주행만 보조하며 Launch/Cart Bomb/충돌 피해 계산은 그대로 유지한다. 알려진 밀착 접촉 반복 피해는 이번에도 수정하지 않는다.
- 기존 질량 반비례 제어 대신 `r = loaded_weight × load_mass_multiplier / cart_base_mass`, `penalty = 1 + amount × r / (1 + r)`의 포화 곡선을 사용한다. 주행·조향 amount=0.35, 제동 amount=0.7. 적재가 커져도 조작 성능이 계속 반감되지 않는다. 실제 질량과 impact_power는 줄이지 않는다.
- `push_strength` 288→576, `follow_strength` 12→18, `steering_strength` 96→432, `max_push_speed` 5.5→6.0. `steering_gain=10`, `max_steering_speed=5rad/s`(기존 4/1.8), `max_follow_correction=6m/s`, `stopped_follow_strength=6`, `braking_strength=360`.
- 플레이어 최고 속도 5m/s는 유지한다. 잡은 카트의 가속도는 기존 Player acceleration=24 제한에 묶지 않는다. 빈 카트 가속 상한 48m/s², 16kg 적재 40m/s²(기존 24/10.29). 조향 가속 36/30rad/s²(기존 8/3.43). 제동 상한 30/21.43m/s²로 적재 시 관성을 남긴다.
- 이동 속도 직접 전달 + 제한된 위치 보정을 유지한다. 정지 후에는 더 낮은 위치 보정 이득을 사용한다. Transform 회전/위치 변경, 충돌 비활성화, 상품 고정은 추가하지 않았다.
- 입고 경로: Loading/Backroom → 중앙 폭 5m 후면문 → Store. 후면 깊이 14→6m, 전체 바닥 18×26→18×18m. 기본 카트 위치는 (0,-3), 매장 주요 통로 (0,3)까지 직선 6m(이전 꺾인 검증 경로 약 18m). 문까지는 3m다. 매장 진열대 배치와 사이 통로 2.2m는 유지한다.
- 배송·상품·진열 규칙과 기존 Prototype Cart Test Zone은 유지한다. Prompt 3 검사에서 구형 위치/경로만 새 배치에 맞췄다.
- 수동 확인: 빈 카트 직진 → 이동 중 좌/우 및 90도 회전 → 16~22kg 적재 반복 → 문을 직진 통과 → 진열/재Grab → Tap/Full/Cart Bomb. 손맛과 과적 산포는 사람의 확인이 필요하다.
- Prompt 3.1의 빠른 카트와 직선 입고 동선은 Prompt 4에서도 유지한다.

### Prompt 3에서 유지한 업무 기반

- 최종 검사: Prompt 0/1/1.1/2/2.1 = 22/48/40/41/28개, Prompt 3 = 32개, 총 211개 통과. 임포트·기본 Main(고정 60fps, 420프레임, 첫 배송 6개 생성)·모든 최종 검사 로그 오류 0건. `.godot/final3_*.log`에 기록한다.
- 실제 검사: 캔+가전 9kg 카트 적재, 엇갈린 출입구와 직각 코너 통과, 상품 3종 각 1개 정상 진열, 재Grab/Charge Throw, 잘못된 진열, 캔 9개 물리 배치 시 8개 집계, 주기적 도착/출발, 손에 든 상품과 하역한 상품 보존을 확인했다. 수동 조작감은 아래 절차로 별도 확인한다.
- 기본 실행은 `Main → MartGraybox`. 기존 PrototypeTestRoom은 별도 씬/F6, Main Inspector의 `start_in_prototype`, 또는 `-- --prototype`으로 유지한다. 기존 회귀 검사는 Main의 prototype 설정을 사용한다.
- 현재 Graybox: 후면 Loading Area(z=-6~-3)와 Backroom(-3~0)은 막힘 없는 하나의 공간이며 Store Floor(0~12)와 중앙 폭 5m 문으로 연결한다. 진열대 사이는 2.2m로 카트 폭 1.8m보다 약간 넓다. 입구는 손님 생성/퇴장 기준점이며 기존 계산대 공간에는 Prompt 4의 SCAN/PAY 계산대가 있다.
- `mart_graybox.gd`는 실행 시 primitive 바닥/벽/표지판을 만든다. 정적 구조를 조정할 때 이 스크립트의 좌표를 수정한다. 플레이어·카트·상품·진열대 인스턴스와 배송 설정은 마트 씬에 있다.
- `DeliveryManager`: 첫 배송 5초, 도착 간격 120초, 체류 60초. 트럭은 도착/출발 시 표시와 충돌을 전환한다. `DELIVERY` 표시와 남은 시간으로 알린다. 운전·차량 이동 애니메이션·사운드는 없다.
- 배송 방식 B: 트럭 옆 전용 팔레트에 Can/Watermelon/Appliance를 각 2개, 총 6개 실제 RigidBody로 생성한다. 공통 GrabbableBody에 `product_type`만 추가했으며 Grab/Throw 코드는 공유한다. 데이터는 각 상품 씬 Inspector에서 수정한다.
- Can: price=5, weight=1, 파란 원통 / Watermelon: 50, 4, 초록 구 / Appliance: 500, 8, 주황 상자. 원통·구는 실제로 구르거나 넘어질 수 있다.
- 출발 시 이번 배송분 중 팔레트 영역에 남은 물체만 Left Behind로 기록하고 회수한다. 밖으로 옮겼거나 손에 든 상품은 유지한다. Delivered/Unloaded/Left Behind 로그와 `last_result`만 있고 금전 정산은 없다. UI의 하역 수는 현재 팔레트 밖/손에 든 수량이다.
- 팔레트 생성 위치가 막혀 있으면 해당 위치는 건너뛴다. `max_active_products=36`은 장시간 프로토타입의 무한 생성 방지용이며 카트 적재 제한이 아니다. 한도 도달 시 다음 배송까지 기다린다. 120초 간격은 도착→다음 도착 기준이며 체류 시간을 더 길게 설정하면 이전 차량 출발 후 최소 0.1초를 둔다.
- `StockShelf`: Can 8 / Watermelon 5 / Appliance 3. StockZone 안의 올바른 종류, 비소유 상태, 선속도≤0.35m/s·각속도≤1rad/s가 0.4초 유지되면 등록한다. `stocked_objects`와 `stock_count`만 추적하고 위치/회전/물리/상호작용은 변경하지 않는다.
- 영역 밖으로 이동하거나 다시 집으면 수량이 줄어든다. 잘못된 상품과 초과 수량은 그대로 물리적으로 놓을 수 있다. 자동 정렬·고정·슬롯 인벤토리는 없다.
- 중요: 카트를 비벼 반복 피해가 나는 기존 동작은 사용자 지시대로 변경하지 않는다. 전투 방향 결정 이후 검토한다.
- 수동 검증: F5 → 5초 후 우측 팔레트 상품 확인 → 직접 Carry 또는 카트에 Drop → 넓은 후면문 직진 통과 → 같은 색 Shelf에 놓고 수량 확인 → 다시 Grab → 다른 색 Shelf/과적/투척 시도. 60초 뒤 트럭 출발과 남긴 상품 회수를 확인한다. F8→F5 초기화.
- 제한: 상품 라벨은 디버그용이라 과적 시 겹칠 수 있다. 적재물 산포/구르기는 의도된 물리 결과이며 수동 동선/과적 조작감 확인이 필요하다. 진열대는 정적인 충돌체다. 박스 개봉·라운드·전체 금전 정산·세이브는 없다.

### 이전 단계에서 유지한 기반
- Godot 4.x / GDScript / 3D PC / Compatibility 렌더러. 로컬 단일 플레이어 기반이다.
- `Main → PrototypeTestRoom → PlayerStart → Player`로 진입한다.
- 기존 20×20 테스트 방에 북쪽 6×24m 카트 통로를 연결했다. 기존 상품 5개·타깃 2개를 유지하고 카트 1개, 카트 타깃, 9도 경사로를 추가했다.
- Player는 CharacterBody3D, 캡슐 충돌, 1인칭 카메라다. 몸체 메시는 시야를 가리지 않도록 그림자 전용이다.
- Prompt 0의 Action 기반 WASD, 마우스 시점, 중력, 충돌, Space 점프를 유지한다.
- Esc로 마우스 잠금을 전환한다. 포커스 상실 시 잠금을 해제하며 Esc로 재개한다. 해제 중 이동 입력은 멈추고 중력·충돌은 유지한다.
- 이동 속도·가속·점프·감도는 Inspector에서 조절한다.
- `Player/Interaction`이 입력·카메라 ray 선택·거리 제한·한 물체 소유·조절 변수를 담당한다. 좌클릭은 Grab/Drop, 우클릭은 누르면 충전/떼면 Throw, E는 계산대 SCAN/PAY 상호작용에 사용한다. Crosshair는 흰색(기본), 초록색(잡기 가능), 주황색(들고 있음)이다.
- `GrabbableBody`는 공통 RigidBody3D 스크립트다. 물체별 `price`, `weight`, 색상, 이름만 설정하며 `weight`를 실제 `mass`에 반영한다. 개별 상품 스크립트나 DB/Inventory는 없다.
- Carry 중에도 물리 시뮬레이션/CCD/환경 충돌을 유지한다. 중력을 일시 해제하고 `_integrate_forces`에서 제한된 가속도로 목표 속도를 따라간다. Transform 고정/순간 이동/카메라 자식화는 하지 않는다.
- Hold 목표는 카메라에서 구체 sweep으로 여유 공간을 검사한다. 카메라 주변이 끼면 Drop, 물체가 4m 이상 뒤처지면 Drop한다. 플레이어와의 충돌만 잠시 제외하고 Drop/Throw 후 서로 분리되면 복원한다.
- Charge는 우클릭 Press로 시작하고 물리 시간에 따라 `q = clamp(held_time / max_charge_time, 0, 1)`로 증가한다. 최대 충전 후에도 계속 들고 있으며 Release 시에만 던진다. 빈손 Press는 무시한다.
- Drop, 소유권 상실, 물체 삭제, 벽/거리 때문에 강제로 놓기, Esc, 포커스 상실 시 충전과 예약된 Release를 취소한다. 취소 후 다시 눌러야 충전된다. Release와 강제 놓기가 같은 프레임이면 놓기가 우선한다.
- Release 시 즉시 소유를 해제하고 전방 impulse를 적용한다. `M = lerp(0.35, 1.5, q)`, `speed = base_throw_force × M / (1 + weight_throw_penalty × max(weight - 1, 0))`, `impulse = mass × speed`. 이름의 force는 기준 속도(m/s)를 뜻한다.
- 피해는 `(base_damage + price × price_damage_multiplier) × lerp(0.5, 1.5, q)`. 가격의 역할은 유지하고 충전만 보정한다. 투척 후 4초 이내 첫 충돌에서만 판정하며 속도 2m/s 미만은 제외한다. 바닥/벽에 먼저 닿으면 해당 투척의 피해 판정은 끝난다.
- 넉백은 충돌 직전 속도 × weight × knockback_multiplier × M이며 최대 impulse를 제한한다. 충전은 실제 속도와 반응 배율 모두에 반영되어 최대 충전의 밀림이 뚜렷하다. 가격은 넉백에 영향을 주지 않는다.
- CCD가 접촉 신호보다 먼저 속도를 줄이는 경우를 위해 최근 3개 물리 틱의 속도 중 가장 큰 값을 충돌 속도로 사용한다. 투척 전체의 최고 속도를 계속 보존하지 않는다.
- Crosshair 24px 아래에 80×8px Charge Bar가 나타난다. 어두운 배경 위 주황색으로 채워지고, 투척/취소 시 값 0과 숨김으로 돌아간다. 숫자·사운드·카메라 흔들림은 없다.
- 빨간 DAMAGE 타깃은 고정 위치에서 피해를 비교한다. 보라색 KNOCKBACK 더미는 피해와 물리 반응을 함께 표시한다. HP 0이면 회색이 되고 추가 피해를 받지 않는다. 플레이어 HP/NPC가 아닌 테스트 장치다.

## 조절 값
`scenes/player/player.tscn`의 **Interaction** 노드 Inspector에서 조정한다.

| 변수 | 기본값 |
| --- | --- |
| grab_distance / hold_distance | 2.8m / 1.7m |
| hold_strength | 12 |
| max_carry_speed / max_carry_acceleration | 8 / 45 |
| break_distance | 4m |
| base_throw_force / weight_throw_penalty | 18 / 0.25 |
| max_charge_time | 1.2초 |
| min_throw_multiplier / max_throw_multiplier | 0.35 / 1.5 |
| min_charge_damage_multiplier / max_charge_damage_multiplier | 0.5 / 1.5 |
| base_damage / price_damage_multiplier | 2 / 0.04 |
| impact_min_speed | 2m/s |
| knockback_multiplier / max_knockback_impulse | 0.15 / 18 |

물체별 `carry_radius=0.49m`는 0.55m 큐브를 감싸는 보수적인 검사 반지름이다.
타깃별 `max_hp=100`, `target_mass=3`, `knockback_drag=4`를 조절할 수 있다.
테스트 데이터: A(5,1), B(5,8), C(50,4), D(500,1), E(500,8), 순서는 (price, weight).

## 현재 알려진 제한
- 좁은 공간에서 자동으로 놓는 것은 안정성을 위한 동작이다. 모서리/여러 물체 사이의 작은 흔들림까지 완전히 제거한 제약 솔버는 아니다.
- 초기 큐브 외 Prompt 3 상품 3종과 Prompt 5 캐릭터 캡슐까지 검증했다. 더 큰 물체나 다른 형상을 만들 때 `carry_radius`도 맞춰야 한다. 일반 상품의 회전은 감쇠만 적용하며, CarryableCharacter의 회전 잠금과 구분한다.
- 무거운 물체는 수평 속도가 낮아 가까이에 떨어진다. 약한 투척은 타깃에 더 가까이 접근해 직격시킨다. 바닥을 먼저 맞히면 피해가 없다.
- 충전량은 물리 틱 단위라 아주 짧은 입력은 같은 최소 세기로 처리될 수 있다. 넉백의 최종 이동량은 접촉 지속 시간과 각도에도 영향을 받는다.
- 타깃 사망/물체 위치를 초기화하려면 F8로 종료 후 F5로 재실행한다. 별도 리셋/세이브 시스템은 없다.
- 테스트는 실제 물리와 입력 Action을 사용하지만 손으로 느끼는 조작감 및 복잡한 끼임 상황은 추가 플레이 테스트가 필요하다.

## Shopping Cart 구조
- `ShoppingCart`는 독립 RigidBody3D다. 바닥·낮은 벽·손잡이·구형 바퀴 충돌체로 구성한다. 질량 중심을 낮추고 각 감쇠를 적용하며 축은 잠그지 않는다. 개별 바퀴 조인트/서스펜션은 없다.
- 주황색 손잡이의 작은 Area만 `cart_handle`로 선택한다. 상품 ray와 같은 첫 충돌 판정을 쓰므로 상품을 보면 상품, 손잡이를 보면 카트가 선택된다. 카트를 들고 있는 동안 좌클릭은 놓기다.
- PlayerInteraction의 `held_object`는 공통 RigidBody3D이며 상품/카트/CarryableCharacter로 동작을 분기한다. 상품·카트의 충전 상태·입력·취소·게이지는 하나를 공유하고 캐릭터 충전은 차단한다. 카트에 일반 물체 Carry를 복사하지 않는다.
- 카트 제어는 PlayerController가 같은 물리 틱에 전달하는 이동 속도 + 목표 거리 오차 보정을 사용한다. 플레이어 가속도도 카트 가속 상한에 맞추며, 막힌 차체를 향하거나 멀어지는 플레이어의 방사 방향 속도를 제한한다(중심 거리 1.75~2.65m). Transform 순간 이동/고정은 하지 않는다.
- Grab 중 현재 플레이어/카트 쌍에만 양방향 collision exception을 적용한다. Drop/Launch/씬 제거 시 복구한다. 상품·벽·타깃 충돌과 비탑승 플레이어의 충돌은 그대로다. 카트만 별도 비상 해제 거리 6m를 쓰며 상품은 기존 4m다.
- 바구니 Area 안에 있고, 로컬 중심점이 내부 범위에 있으며, 현재 잡히지 않은 GrabbableBody의 `weight`를 매 물리 프레임 합산한다. 슬롯·상품 생성/소멸·부모 변경은 없다. 적재 중 라벨은 숨겨 시야를 확보하고 꺼내면 복원한다.
- `effective_mass = cart_base_mass + loaded_weight × load_mass_multiplier`. RigidBody의 mass는 차체 기본 무게만 유지하여 독립된 상품의 물리 질량을 다시 더하지 않는다. effective_mass는 제어·발사·피해에 사용한다.
- Grab 중 가속/조향 상한은 `strength / (cart_base_mass × control_penalty)`다. 포화 중량 패널티는 Prompt 3.1 항목을 참고한다. 자유 상태의 구름 저항과 발사·충돌 중량 계산은 유지한다.
- Launch 속도는 `launch_force × 기존 Charge 배율 / (1 + launch_load_penalty × loaded_weight / cart_base_mass)`다. 수평 시선 방향으로 손을 놓고 한 번의 임펄스를 준다. 현재 적재물에도 같은 속도 변화에 해당하는 임펄스를 한 번만 전달하며 이후 속도를 맞추거나 고정하지 않는다.
- 카트 충돌 피해는 `speed × effective_mass × impact_damage_multiplier`, 넉백은 속도 벡터 × effective_mass × impact_knockback_multiplier로 계산하고 각각 상한을 둔다. 같은 발사의 같은 대상은 한 번만 판정하고 일반 재접촉에도 cooldown을 둔다.
- Cart Bomb: 발사한 상품을 기존 GrabbableBody의 첫 외부 충돌 피해 경로로 활성화한다. 바구니/적재물끼리의 접촉은 물리적으로 유지하되 피해 기회를 소모하지 않는다. Grab하면 해제된다. 바닥 등 첫 외부 접촉에서 종료되어 지속 피해를 막는다.
- 강한 타깃 충돌에서는 적재물에 제한된 상승/전방 임펄스를 전달한다. 이는 충돌 충격을 강조하는 프로토타입 보정이며, 실제 충돌체를 넘어 튀어나와야 한다. 상품 위치를 옮기거나 자동으로 타깃을 맞히지 않는다.
- 탑승은 점프해서 바구니 바닥에 서는 방식이다. CharacterBody3D의 기존 이동 발판 처리를 활용하며 별도 탑승 모드/인벤토리는 없다. NPC 운반은 Prompt 5의 별도 CarryableCharacter를 사용한다. 안에서 자신의 카트 손잡이를 잡는 것은 막는다.
- 고속 사고에서 제한된 회전 임펄스로 뒤집힐 수 있다. 추가 회전 충격은 잡기/발사 후 한 번만 허용하고 각속도를 제한해 연속 충격으로 날아가는 것을 막는다. 접근 가능한 손잡이를 다시 잡으면 실제 복원 토크를 준다. 회전값 재설정이나 Reset Cart 버튼은 없다.

### 카트 Inspector 주요 값
`scenes/interactables/shopping_cart.tscn`의 루트에서 조절한다.

| 변수 | 기본값 |
| --- | --- |
| cart_base_mass / load_mass_multiplier | 12kg / 1 |
| push_strength / follow_strength | 576 / 18 |
| stopped_follow_strength / max_follow_correction | 6 / 6m/s |
| steering_strength / max_push_speed | 432 / 6m/s |
| steering_gain / max_steering_speed | 10 / 5rad/s |
| load_control_penalty / load_braking_penalty | 0.35 / 0.7 |
| braking_strength | 360 |
| handle_distance / emergency_break_distance | 2.1m / 6m |
| rolling_resistance | 0.6 |
| launch_force / launch_load_penalty | 12 / 0.45 |
| impact_min_speed / impact_cooldown | 2m/s / 0.8초 |
| impact_damage_multiplier / max_impact_damage | 0.12 / 60 |
| impact_knockback_multiplier / max_knockback_impulse | 0.08 / 18 |
| spill_min_speed / spill_lift_multiplier | 5m/s / 0.75 |
| spill_forward_multiplier / max_spill_lift | 0.35 / 6m/s |
| crash_flip_speed / crash_torque_multiplier | 12m/s / 2 |
| max_crash_torque_impulse / max_spin_speed | 120 / 6rad/s |
| righting_torque | 120 |

### 카트 제한 / 수동 테스트
- 상품은 거친 조향·충돌에서 빠질 수 있다. 꽉 채우거나 높이 쌓으면 흔들림이 커진다. 바구니 부피 검사는 현재 큐브 크기를 기준으로 한다.
- 급격한 180도 시점 회전, 여러 물체 사이의 끼임, 높게 쌓은 화물은 추가 수동 튜닝 대상이다. 일반 전후진·회전과 벽에 막힌 상황은 자동 검사하며, 6m 이상 비정상 분리에서는 손을 놓는다.
- 뒤집힌 상태는 손잡이 쪽으로 접근해 잡는다. 벽과 바닥 사이에 완전히 끼면 먼저 공간을 확보해야 할 수 있다.
- 플레이어는 점프로 옆 벽을 넘어 탑승한다. 싱글 플레이에서 함께 움직이는 것을 확인하려면 카트가 경사로에서 구를 때 올라타거나 테스트의 외력 검사를 사용한다. 두 번째 플레이어는 없다.
- F5 → 오른쪽 카트의 주황 손잡이를 보고 좌클릭 → WASD/시점으로 밀기·당기기·조향 → 다시 좌클릭으로 놓기.
- 기존 A~E를 집어 열린 바구니 위에서 Drop한다. 카트 라벨의 총 kg와 빈/적재 조작감을 비교한다.
- 같은 위치에서 Tap/Full Charge 발사 후 보라색 카트 타깃의 HP·넉백을 확인한다. 여러 상품을 싣고 Full Charge하면 Cart Bomb을 검증할 수 있다.
- 왼쪽 RAMP에서 천천히 밀기/자유 구르기와 Full Charge 사고를 비교하고, 뒤집힌 뒤 손잡이를 잡아 세운다. 테스트 전체 초기화는 기존 F8 → F5다.

### Prompt 2 검증 결과
- 최종 자동 검사 41개 통과. 손잡이/상품 선택, 밀기/당기기, 중량 합산/제어 차이, 발사, 실제 타깃 피해/넉백, Cart Bomb, 점프 탑승/이동 발판, 경사로, 고속 사고 뒤집힘, 뒤집힌 상태에서 실제 Grab 복구를 검사했다.
- 초기 속도: 빈 카트 Tap 4.15m/s / Full 17.90m/s, B+E(16kg) 적재 Tap 2.57m/s / Full 11.17m/s.
- 비슷한 실제 충돌 속도 7.05 / 7.08m/s에서 빈 카트 피해 10.15 / 적재 카트 피해 23.80, 넉백 impulse 6.77 / 15.87.
- Cart Bomb: A~E 5개, 총 22kg 적재 → Full Charge → 차체 피해 33.66(1회), 상품 4개 이탈, 개별 상품 피해 33(1회)을 확인했다. 이탈 개수와 충돌 순서는 달라질 수 있다.
- 별도 관성 확인에서 같은 초기 속도로 1.5초 자유 주행 시 빈 카트 약 9.76m, 16kg 적재 약 9.85m였다. 관성 차이는 작으므로 수동 조작감 튜닝 여지가 있다.

## Prompt 2.1 구조 / 검증

- 최종 Godot 4.7.2 검사: Prompt 0 22개 / 1 48개 / 1.1 40개 / 2 41개 / 2.1 28개 통과(총 179개). 최종 로그와 임포트·Main 180프레임 실행 오류 0건. 로그: `.godot/final21_*.log`.
- 첫 회귀 실행은 창 포커스 상실로 입력 검사가 실패하여 재실행했다. Cart Bomb 산포로 좁은 타깃에 상품이 빗나가는 비결정성을 줄이기 위해 Prompt 2 자동 검사에서만 타깃 폭을 3.6m로 확대했다. 상품 이탈·개별 피해 판정은 그대로 검증하며 실제 씬은 변경하지 않았다. 최종 결과는 적재 5개/이탈 4개/차체 1회/상품 1회 타격이다.
- 변경 파일: `player_controller.gd`(이동 의도 전달·몸 밀기), `shopping_cart.gd`(직접 구동·거리 유지·충돌 예외), `player_interaction.gd`(카트 비상 거리), `tests/prompt2_1_smoke.gd`.
- 구동 속도 목표 = 플레이어 이동 속도 + 수평 위치 오차 × `follow_strength`. 힘/가속 상한과 실제 RigidBody 충돌은 유지한다. 입력 대기 타이머는 없다.
- Player 몸 밀기: `min(max_player_push_impulse, closing_speed × player_push_strength × delta / (1 + push_weight_penalty × max(weight - 1, 0)))`. 접촉 법선의 수평 방향으로 중앙 임펄스를 준다. 같은 몸체에 틱당 한 번만 적용하고, 바닥 접촉과 현재 소유 물체는 제외한다.
- 접촉으로 실제 이동 속도가 0이 되어도 이동 의도에 따른 제한된 힘을 유지한다. 상대 물체가 이미 더 빠르게 멀어지면 밀지 않는다. 카트는 effective_mass, 상품/기타 RigidBody는 실제 mass를 사용한다.
- Player Inspector 기본값: `player_push_strength=36`, `max_player_push_impulse=3`, `push_weight_penalty=0.12`, `minimum_push_speed=0.2m/s`.
- 입력 시작 검사에서 빈/16kg 적재 카트 모두 첫 틱에 이동 의도를 전달했다. 다음 물리 결과의 전진 속도는 약 0.36/0.17m/s였다. 동일 65틱 걷기 시험에서 1kg 상품 약 1.94m, 8kg 약 0.11m, 자유 카트 약 0.40m 이동했다. 접촉 조건에 따른 예시 수치다.
- 테스트에는 전후진·연속 회전 중 Grab 유지, 양방향 충돌 예외/복구, 막힌 벽과 플레이어 거리 유지, 실제 몸 밀기 변위, Charge Launch 복구, 들고 있는 상품의 충돌 제외가 포함된다.
- 수동 확인: 빈/16~22kg 적재 전후진·회전·정지, 벽에 밀기와 Drop, 1kg/8kg 몸 밀기, 자유 카트 몸 밀기, Full Charge/Cart Bomb, 점프 탑승을 비교한다. F8→F5로 초기화한다.
- 한계: 자동 입력은 실제 사람이 느끼는 떨림·응답 만족도를 보장하지 않는다. 급격한 180도 회전/비정상 끼임/높이 쌓은 화물은 수동 확인이 필요하다. 몸 밀기 기본값은 기본 60Hz 기준이며 물리 tick rate 변경 시 재튜닝한다.

## 향후 예정 / 현재 미구현
- **다음 작업: Lost Child.** 취객에서 검증한 Character Carry를 재사용하되 부모 찾기/인계는 후속 단계에서 구현한다.
- Cart Rocket, 소화기 가속, 카트 업그레이드, 멀티플레이는 미구현이다.
- 배송 박스 개봉·전체 금전 손실 정산, 플레이어/일반 손님 Carry.
- 취객의 들어서/카트로 퇴장은 Prompt 5에서 구현했다. 미아(부모에게 운반), 사고 손님(미끄러운 바닥), 위험 손님(화재), 도둑(추격)은 아직 기획 단계다.
- 관광버스는 새로운 규칙 대신 기존 업무에 짧은 과부하를 준다.
- 주변 물건 전투 → 근접 무기 → 도검/총기 등 강한 장비. 장비는 주문 → 배송 → 트럭 → 박스 운반 → 개봉으로 얻는다.
- 괴물은 랜덤 점프스케어 대신 미니/중간/강한/최종 보스 progression으로 등장한다. 보스마다 직관적인 특징 하나를 갖고 기존 업무는 가능하면 계속된다.
- 보스 예: KING RAT(먹은 식품 가격만큼 손실), CART DEMON(카트 돌진), FREEZER THING(바닥 결빙).
- 복권은 마트 자금을 사용하며 대부분 손실, 극히 드문 큰 보상을 준다.
- 야간 영업 22:00~06:00, 실제 18~22분 목표. 정상 영업·사건·압박·회복·큰 혼란·보스·마감의 강약을 둔다. Round Director는 핵심 시스템 검증 후 만든다.
- 영수증 정산 항목: Sales, Stolen Goods, Broken Products, Fire Damage, Weapon Expense, Lottery Expense, Lottery Winnings, Profit.
- 회고 통계: Customers, Drunks Removed, Lost Children Found, Thieves Caught, Items Thrown, Cart Collisions, Boss Defeated, Most Expensive Throw.
- 플레이어 체력, 취객 외 특수 NPC, 본격 애니메이션 시스템, 물/화재, 본격 전투, 무기, 보스, 복권, 정산, 멀티플레이, 세이브, 상세 UI/그래픽 모두 미구현. 외부 에셋은 사용하지 않는다.

## Toy Interaction 참고
| 대상 | 향후 검토할 조합 |
| --- | --- |
| 카트 | 적재·밀기/당기기·탑승·속도 축적·던지기 입력 발사·중량별 충돌·상품 튀어나감. Cart Bomb / 소화기 Cart Rocket |
| 상품 | 운반·내려놓기·투척·친구 휘청임/넉백·적 피해·가격별 피해 차이 |
| 대걸레 / 소화기 | 청소/진화 외 플레이어·NPC·적 밀기, 소화기로 카트 움직임에 영향 |
| 박스 | 운반·투척·쌓기·등반·길막. Box Tower |
| 냉동고 | 보관 외 플레이어/NPC/가능한 괴물 진입과 문 닫기. Freezer Prison |
| 캐릭터 운반 | 다른 플레이어·미아·취객·일부 NPC. 취객을 카트로 내보내는 Drunk Delivery |
| 진열대 | 실제 상품 올리기·충돌로 상품 낙하·강한 충격으로 전도 |
| 스캐너 | 정상 계산 외 친구 스캔 시 beep/$0.99 같은 보상 없는 장난 반응 |

## 개발 원칙 / 다음 작업
1. 실행 안정성 → 조작감 → 단순한 구조 → 수정 가능성 → 코드 미관 순으로 판단한다.
2. Prototype first. 데이터·입력·상호작용·물리·UI를 필요에 따라 분리하되 추상 계층이나 미래 기능을 미리 만들지 않는다.
3. `scripts/player`의 이동과 `scripts/interaction`의 상호작용/물리 책임을 구분한다. 상품별로 Grab/Throw 로직을 복사하지 않는다.
4. 마트 Graybox에서는 공통 상품·카트를 재사용하되 입고/진열 규칙을 물리/입력 스크립트에 섞지 않는다.
5. 네트워크 권한/동기화 방식과 밸런스는 추후 결정한다. 지금 네트워크 추상 계층을 만들지 않는다.

## 검증 / 수동 테스트
최신 전체 결과는 문서 상단 인수인계 및 Prompt 5 최종 검증(총 327개)을 참고한다. 아래는 초기 물리 프로토타입 룸의 검사 내용과 수동 확인 사항이다. 기본 F5의 Mart 씬과 혼동하지 않는다.
프로젝트 임포트와 렌더링 화면 확인도 완료했다. 물체 생성/데이터, 거리 제한/벽 뒤 Grab 차단,
Grab/Carry/Drop/Throw, 이동/회전 중 Carry, 중력 복원, 바닥/벽 충돌, 가격별 실제 피해,
무게별 실제 속도/거리/넉백, 중복 피해 방지, HP 0 색상 반응을 검사한다.
위의 Prompt 1 검사는 충전 도입 후 Throw 입력만 절반 충전 후 Release로 갱신하며 기존 검사 항목은 유지한다.
추가 검사 `tests/prompt1_1_smoke.gd`는 Press/Hold/Release, 0~1 제한, 각 취소 경로,
탭/절반/최대 거리와 실제 속도, 가격 피해, 넉백 증가와 상한, 게이지를 검증한다.
동일 높이 수평 투척, 첫 바닥 접촉 직전 거리: 1kg Tap 2.99m / Half 7.91m / Full 12.82m;
8kg Tap 1.09m / Full 4.66m. 1kg 실측 초기 속도: 6.28 / 16.60 / 26.91m/s.
price 5 실제 피해: Tap 1.1 / Full 3.3, price 500 Full 피해 33.
동일 1kg 물체의 테스트 충돌 impulse는 Tap 0.36 / Full 6.00이며 실제 더미 이동량도 Full이 컸다.
물리 수치는 프레임과 접촉에 따라 달라지므로 상대적인 차이만 판정한다.
Prompt 0 회귀 검사는 새 물체를 테스트 씬에서만 제거해 기존 빈 방의 이동 조건을 유지한다.
Prompt 1/1.1은 카트/경사로를 테스트에서만 제거하여 기존 상품 투척 경로를 유지한다. Main에는 모든 테스트 시설이 존재한다.

1. F5 실행. 물체 가까이 이동해 아래를 보고 Crosshair가 초록색일 때 좌클릭한다.
2. A~E를 각각 들고 WASD 이동/마우스 회전한다. 한 번에 하나만 따라와야 한다.
3. 다시 좌클릭해 자연스럽게 떨어지는지 확인한다.
4. A를 잡고 우클릭을 짧게 눌렀다 떼기 / 약 0.6초 / 1.2초 이상 충전 후 떼기를 비교한다.
5. 같은 위치/각도/Full Charge에서 A(1kg)와 B(8kg)의 속도와 거리를 비교한다.
6. 빨간 DAMAGE 타깃에 A와 D를 Full Charge로 직격시켜 라벨/Output의 Hit 3.3과 33을 비교한다.
7. 보라색 KNOCKBACK 타깃에 같은 물체를 Tap/Full Charge로 직격시켜 강한 투척의 밀림을 확인한다.
8. 들고 벽/모서리에 접근하고 아래를 보며 바닥 및 다른 물체와 접촉시킨다. 심한 떨림/관통이 없는지 확인한다.
9. 기존 점프·Esc·Alt+Tab 복귀를 확인한다. 초기화는 F8 → F5다.
10. 충전 중 좌클릭 Drop/Esc/벽에 접근하여 강제 놓기를 시도한다. 게이지가 초기화되고 뒤늦게 우클릭을 떼어도 투척되지 않아야 한다.
