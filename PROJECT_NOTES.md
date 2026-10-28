# NIGHT SHIFT MART — 개발 메모

후속 Codex/Astra 작업은 루트 AGENTS.md → 이 문서 → 관련 Skill 순으로 읽고 현재 단계와 범위를 확인한다.

## Prompt 11.8 — KING RAT Active Combat Loop

2026-10-29 구현·자동 검증 완료. 기존 회귀 **2,473 + 신규35 = 2,508 PASS / 최종0 FAIL**, 최종 선택 로그 Script/엔진 오류0. 시작 Git clean, 변경은 uncommitted 유지. 사용자가11.7 중립/Aggro 동작을 수동 확인했다. Neutral·도발·attacker attribution·12초 Aggro decay는 유지하고 Aggro 이후의 의사결정/이동/공격 박자만 변경한다. Weapon/새 공격/새 Boss/Networking/NavMesh는 추가하지 않았다.

### 원인과 재현

- 기존8초 cooldown 중에는 Player 중심을 향해 Pursuit하다가3.2m에서 모터가0을 반환했다. Charge/피격 회복 후에도 이 generic Pursuit로 돌아갔으므로 긴 정지·추종 시간이 생겼다. Spawn의 기본 공격 대기4초도 첫 전투 시작을 늦출 수 있었다.
- 실제 Main의 Rat과5m 거리 정지 Player(관찰용 HP10000), 열린 중앙 통로에서30초 관찰. 이전: Telegraph4회/2.60초, Charge4회/3.20초, Recovery1.27초, Reposition1.12초, Pursuit21.82초. Pursuit/재배치 중 수평 속도0.25m/s 미만의 총 정지21.82초, 최장 연속6.08초. `.godot/p118_before.log`에 수정 전 측정 보존.

### Combat Decision / 거리 / 이동

- 작은 재사용 `CombatDecision.choose`는 거리·공격 경로·준비 여부로 APPROACH/ATTACK/REPOSITION만 선택한다. 실제 Charge 실행·물리 이동은 KingRat에 남겨 과도한 framework를 만들지 않는다.
- 너무 가까움<2.5m: 뒤/옆으로3.2m spacing 확보. 중거리2.5~7m: 열린 공격 경로이고 cooldown/grace 종료면 즉시 Telegraph. 쿨다운이면 정지하지 않고 약4m 반경을 유지하도록 측면 이동+거리 보정을 한다.7m 초과 또는 공격 경로가 막혔으면 Combat Approach.
- 기존 enum `PURSUIT` 값은 회귀/외부 참조 호환을 위해 유지하지만 이제 의미는 **COMBAT_APPROACH**이며 머리 위 표시도 이 이름을 사용한다. Aggro 이동을 Neutral Food/Zone 분기에서 분리했다. 접근 목표도 열린 경로에서는 Player 중심이 아니라3.2m 앞 공격 위치다. 다음 frame마다 Attack 가능 여부를 먼저 결정한다.
- Reposition: 근접 탈출3.5m/s, 쿨다운 측면 재배치2m/s. 안정된 한쪽 방향과 거리 보정,0.7m body probe로 벽 회피,0.6초 진행 정체 시 방향 변경. 양쪽이 모두 막히면 기존 aisle graph로 접근 경로를 다시 찾는다. 근접 탈출은3.2m 확보까지 유지하여 경계에서 공격/후퇴를 매 frame 바꾸지 않는다.

### 공격 박자 / 장애물 / 피격

| 값 | 이전 | 현재 |
|---|---:|---:|
| Charge cooldown (Telegraph 시작 기준) | 8초 | 4.5초 |
| 초기 공격 대기 | 4초 | 0초 |
| Telegraph | 0.65초 | 0.65초 |
| Charge 최대 시간 / 속도 | 0.8초 / 7.5m/s | 유지 |
| Attack Recovery | 0.3초 | 0.55초 |
| Approach / Roam 속도 | 4.8 / 3.6m/s | 유지 |
| Combat repath / 정체 판정 | 0.8 / 1초 | 0.4 / 0.8초 |

- Aggro가 Spawn 대기를 중단해 다음 physics tick부터 결정한다. Recoil/Stagger 등 명확한 피격 동작은 우선한다. Charge cooldown은 먼 거리에서도 계속 감소한다. Charge miss는 최대 거리 후 Recovery, 실제 Aggro Target hit는 추가0.12초까지 진행 후 Recovery로 연결한다. NPC를 스친 것만으로 돌진을 조기 종료하지 않는다.
- LOS 외에 기존0.63m sweep으로 World/Shelf/Cart를 통과할 공격 경로인지0.2초마다 확인한다. 시야가 있어도 바구니/낮은 장애물로 몸체 경로가 막히면 Telegraph 대기 대신 aisle 우회한다. 바닥 상품에 실제 정체되면 기존 상품 포함 detour를 사용한다. 길찾기 전체를 다시 작성하지 않았다.
- Recoil/Stagger 종료→0.35초 post-hit grace→Combat Decision, Charge Recovery 종료→Combat Decision. 일반 overlap push는 공격으로 취급하지 않는다. Damage30, Knockdown, direction lock, Cart solid와 기존 Product/Cart Damage 공식을 유지한다.
- 최종 같은30초 관찰: Telegraph7회/4.55초, Charge7회/3.63초, Recovery3.97초, Reposition7진입/17.85초, Approach0초(처음부터5m 정지 Target이므로). 추적·재배치 중 정지0초, 비전투 상태0초, 최장 연속 Recovery0.567초, Player HP10000→9790. 이는 자동 고정 배치의 운동/상태 측정이며 수동 전투 손맛이나 모든 장애물의 무정체를 보장하지 않는다. Far/후퇴 Target 접근은 별도 검사로 통과했다.

### 검사 / Known Issues

- `prompt11_8_observation.gd`: 수정 전후 같은30초 관찰, 상태 시간/진입 횟수, 정지 총량/최장 구간, Recovery 다음 동작 공백 측정.
- `prompt11_8_smoke.gd`: 거리별 결정, Mid 즉시 Telegraph, Far/움직이는 Player 접근→Attack, close 탈출, cooldown 각도 변경, strong hit 우선순위/복귀,30초 cadence.
- `prompt11_8_route_smoke.gd`: 선반 LOS 차단→우회→공격, solid Cart 우회, 첫 도발의 초기 대기 제거, Aggro 해제 후 Food/Zone 복귀.
- 기존11.5 속도 검사는 공격 거리 밖으로 Target을10→15m에 배치하여 빠른 접근 기준을 보존한다.11.5 miss 회복은 설정된 새 Recovery 시간을 기다린 뒤 Approach/Reposition 재개를 검사한다.11.6 cooldown 기억 유지 검사는 정지 Pursuit 대신 능동 Reposition을 기대하도록 변경한다. 피격·물리·피해·거리 기준을 완화하지 않는다.
- 전체 회귀 최초 실행에서11.5 extra의 고정 TV 검사1개 실패: Rat이 `(2.58, 0, 16.00)`까지 능동 재배치로 우회했으나 기존 검사가 요구하는 `_pursuit_detour_left` 타이머 발동은 없었다. 정체 복구 자체를 계속 검증하도록 이 fixture의 Player도10→15m로 이동하여 TV를 공격 거리 진입 전에 만나게 했다. 재검사26 PASS, `detoured=true`, Rat `(-1.04, 0, 16.04)`. 실제 전진·정체 타이머·Target 유지 기준 모두 보존. 실패 원본 `.godot/p118_reg_11_5_extra.log`, 재검사 `.godot/p118_retry_11_5_extra.log` 보존.
- 신규 core26 + route9 PASS. Shelf 차단 우회 후 Rat `(-3.77, 0, 14.20)`, Target 거리6.92m에서 Telegraph, 열린 공격 경로 재확보→공격 대기0.017초. 고정 Cart 우회→Telegraph, Cart solid, 최초 도발 즉시 결정,12초 기억 만료 후 Food/Zone 복귀 통과. 기존 중립10초·실제 Product/Cart 도발·피격/Revive·Tourist/Chaos·cargo 회귀 모두 통과.
- 최종 로그 집계 `.godot/p118_results.txt`: 회귀38개 실행 + 신규2개 실행, 중복 재검사 PASS는 합산하지 않음. `.godot/p118_final_11_8.log`에30초 측정, `.godot/p118_final_11_8_route.log`에 장애물 결과. Headless editor import, Main headless7200 physics ticks(120초), 창 Main600 ticks 모두 종료0·오류0 (`p118_main_import/headless/window.log`). `git diff --check` 통과. Main 창 검사는 자동 시뮬레이션이며 수동 조작 완료를 뜻하지 않는다.
- 수동: I→U OFF→R 후 중립 관찰, Pan 투척으로 전투 시작,4~6m에서 Telegraph, Main aisle 도주, 가까이 붙기, Charge Dodge, Shelf 반대편 이동, TV/Pan 반격과30초 전투 박자를 확인한다. 수동 조작 결과는 아직 미확인.
- 유지: NPC Knockdown Mesh/Collider mismatch, Cart Contact Repeated Damage, Day Reset Prototype, Monster/Character visual overlap Final Combat Polish, 극단적 Cart 과적 Physics Chaos. 고정 aisle graph는 Full Navigation이 아니며 모든 통로가 봉쇄된 경우의 경로 보장은 없다.

## Prompt 11.7 — KING RAT Provocation / Aggro

2026-10-27 구현·자동 검증 완료. 기존 회귀 **2,427 + 신규46 = 2,473 PASS / 0 FAIL**, 최종 선택 로그 Script/엔진 오류0. 시작 Git clean, 변경은 uncommitted 유지. 사용자가11.6 flat cargo 안정화와 Recoil→Reposition 개선을 수동 확인했다. 이번 변경은 Weapon/새 Boss/네트워크/Threat Table 없이 기존 전투의 시작·종료 조건과 공격자 전달만 확장한다.

### 원인 / Neutral / 도발

- 기존 `update_awareness`는22m 이내 LOS만으로 매 frame 전투 기억을6초로 갱신했다. 따라서 상품 탐색 중 지나가는 Player도 Food보다 먼저 추적했다. 기존11.5 회귀도 이 자동 전투 시작을 전제로 했다.
- Spawn은 `is_aggro=false`, `aggro_target=null`. 중거리 LOS/상품 Grab/목표 상품 가져가기는 새 Aggro를 만들지 않는다. 기존 Food/Zone 이동을 그대로 우선한다.
- 실제 양수 피해로 HP가 감소했고 유효한 Alive Player instigator가 있으면 해당 Player를 목표로 한다. 가장 최근 유효 공격자가 우선이며 큰 Threat Table은 없다.0피해/무효·Downed 공격자는 제외한다. 공격자 없는 환경 Damage는 새 Aggro도, 기존 Player 기억 갱신도 만들지 않는다.
- Self-defense: `player_health` 그룹의 각 Alive Player를 확인한다. LOS가 있고2.5m 이내 상태가 같은 Player 기준1.25초 연속 유지되면 도발한다. 거리 이탈/가림은 해당 체류 시간을 초기화한다. 여러 Player의 접촉 시간을 합산하지 않으며 벽 반대편에서 가까운 것만으로 도발하지 않는다.

### 공격자 전달 / API

- 작은 `AttackAttribution`은 Player WeakRef와8초의 physics-frame 기반 만료 시점을 보관한다. Grab/Drop/Throw 때 기록하고, 카트는 Grab/운전 중/Launch 때 갱신한다. Cart Bomb 상품은 Launcher 기록을 전달받는다. 오래 방치한 물체의 접촉을 영구 소유권으로 해석하지 않는다.
- 상품·Cart의 실제 충돌이 `CombatTarget`이면 `receive_impact(amount, impulse, instigator)`로 전달한다. 기존 NPC/TestTarget에는 기존2인자 호출을 유지한다. 상품 price/charge/weight 및 Cart Damage 공식, hit 횟수, 산개, Known Issue인 Cart rubbing Damage는 변경하지 않는다.
- `CombatTarget.receive_damage(amount, source=null, instigator=null)`를 통해 향후 Weapon도 명시적인 공격자를 전달할 수 있다. 현재 source로부터 공격자를 임의 추정하지 않는다.0 이하/비정상 피해는 기존 검증에서 차단한다.
- 삭제된 Player가 deferred impact와 겹칠 수 있으므로 instigator의 Node 형식을 진입 전에 강제하지 않고 `is_instance_valid` 후 CharacterBody3D/PlayerHealth를 검사한다. 최초 신규 검사에서 삭제된 target을 typed Node 인자로 넘기면서 생긴 Script Error를 이 방식으로 수정했다. 초기 로그 `p117_new.log`는 보존한다.

### Aggro Combat / 해제

- Aggro 중에는 기존 LOS/last_known_position 및 aisle 우회를 재사용한다. awareness22m, Roam3.6/Pursuit4.8/Charge7.5m/s, Charge cooldown8초/telegraph0.65초/피해30, recoil/stagger/3.2m spacing은 유지한다.
- 기억 기본값은 `aggro_memory_time=12초`. 대상이 시야에 들어오거나 유효 공격자 피해를 다시 주면 갱신한다. 가려졌거나 awareness 밖이면 마지막 위치를 추적하며,12초 동안 갱신되지 않으면 해제한다. 최신 instigator는 거리 밖에서도 공격으로 도발할 수 있다.
- 해제 시 target/memory/추적 경로를 지우고 현재 위치의 nearest zone에서 실제 Product를 재탐색한다. Store 중앙으로 teleport/강제 복귀하지 않는다. Recoil/Stagger가 진행 중이면 마친 뒤 중립 행동을 재개한다. 대상 삭제/Downed도 즉시 해제한다.
- 미래 다인 Player는 공격 event의 instigator reference로 교체 가능하며, 근접 방어 후보도 등록된 Player별로 처리한다. Networking은 구현하지 않았다.

### 검사와 수동 확인

- 신규 `prompt11_7_smoke.gd`:10초 중립 관찰, 실제 Grab→Throw 충돌, Cart Bomb, 첫 피격 회복,12초 도주/재도발, 근접 스침/체류, 환경 피해, 다른 Player 재타겟/삭제/Downed, attribution 만료.
- 신규 `prompt11_7_food_smoke.gd`:실제 음식 목표 Grab 후 재탐색, 해제 후 현위치 탐색, 벽 너머 근접 방어 차단, LOS memory/피해 갱신, 카트 driver attribution.
- 기존11.4 Charge,11.5 추적/Chaos,11.6 피격·공격 간격 회귀는 자동 LOS 도발 대신 명시적인 도발 전제를 추가했다. 기존 이동·우회·피해·산개·회복 기준은 유지한다.11.5의 기존6초 기억 시간 검사만 Inspector 값6초로 지정하여 기존 계약을 그대로 검사하고, 새 기본12초 해제는11.7에서 검사한다. Neutral 관찰 검사는 도발하지 않는 별도 fixture다.
- 최종 신규 기본34개/음식·환경12개 모두 통과. 최초 `p117_new.log`의 삭제 target 오류는 수정 후 동일 제거 검사에서 통과했다. 실제 Throw/Cart Bomb의 attacker 전달, 만료된 소유자 기록의 실제 투사체 피해가 새 Aggro를 만들지 않는 것, 다른 Player 재타겟 및 삭제/Downed, 근접 스침과 지속 체류, 가려진 위치 기억/해제/재도발을 검사했다.
- 전체0~11.6 회귀2,427개는 `p117_reg_<stage>.log`, 신규 최종은 `p117_final_11_7.log`/`p117_final_11_7_food.log`. 선택 목록과 합계는 `.godot/p117_results.txt`에 보존한다. 초기 실패/중복 재실행은 합산하지 않는다. 임포트와 Main headless7,200ticks/120초, 실제 창600ticks 모두 종료코드0·오류0(`p117_main_import.log`, `p117_main_headless.log`, `p117_main_window.log`).
- 중립60초 관찰: visited zones[0,1,2], 총 이동176.59m, 실제 상품 손실330. 도발 후120초 혼합: Tourist12명 중11명 상품 방문, Queue peak10, Pursuit5,490ticks, Rat 총 이동100.05m, 관찰 Player HP10000→9550. Customer 업무와 도발 후 Combat을 각각 유지했다. 혼합 검사는 시작 시 명시적으로1피해를 주며, 중립 검사는 공격하지 않는다.
- 수동: I→U OFF→R 후5~10m에서 관찰/빠른 스침/음식 가져가기, Pan·TV 투척으로 전투 시작, 선반 뒤 장거리 도주 후12초 해제, 재공격으로 두 번째 전투,2.5m 이내 체류로 Self-defense를 확인한다. 자동 통과만으로 손맛을 확정하지 않는다.
- 유지: NPC Knockdown Mesh/Collider mismatch, Cart Contact Repeated Damage, Day Reset Prototype, Monster/Character visual overlap Final Combat Polish, 극단적인 Cart 과적 Physics Chaos. 고정 aisle route의 복잡 장애물 한계도 남는다.

## Prompt 11.6 — Flat Cargo / KING RAT Post-hit Recovery

2026-10-26 구현·자동 검증 완료. 기존 회귀 **2,386 + 신규41 = 2,427 PASS / 0 FAIL**, 최종 선택 로그 Script/엔진 오류0. 작업 시작 Git clean. Weapon/새 콘텐츠/Navigation 전면 교체는 없으며 변경은 uncommitted로 유지한다.

### 재현과 Cargo 수정

- 실제 Main Cart에 Pan 단독(수평/0.15rad 기울기), Pan+Can, Pan+Watermelon, Pan2개를 적재했다. 2초 정착 후5초 측정하고 별도로 직진3초/회전1.5초/정지1.5초를 실행한다. 변경 전 `.godot/p116_before.log`, 신규 검사 `.godot/p116_new.log`. 이 배치에서는 큰 튀김은 재현되지 않았다. 관찰된 문제는 작지만 지속되는 접촉 속도이며 Pan+Can의 평균 선속도0.00629m/s가 단독보다 컸다. 수동 보고의 모든 배치를 재현했다고 주장하지 않는다.
- Pan은 이미 0.85×0.12×0.48m 단일 BoxShape/BoxMesh이고 COM은 자동 중앙(0,0,0)이다. 높은 COM이나 복잡한 손잡이 compound collider가 원인은 아니므로 형상·COM·질량·basket 충돌은 변경하지 않았다. 기존 assist는 낮은 상대 속도만 확인하고 지속 지지 접촉 여부를 구분하지 않아 미세 접촉 회전을 충분히 감쇠하지 않았다.
- 상품명 분기 없이 Definition의 가장 얇은 축이 다음 축의30% 이하인 물체에 적용한다. 실제 상향 접촉 normal>0.8, Cart 또는 다른 cargo 지지, 낮은 상대 속도<0.25m/s/회전<0.35rad/s, 회전을 반영한 높이≤두께+다음 축×0.12, rim 안 footprint가0.35초 유지되어야 한다. 원래 Y축이 두꺼운 상품도 옆으로 평평하게 놓이면 같은 판정을 사용하며 회전된 실제 외곽 크기로 rim 여유를 확인한다.
- 기존 assist에 회전 감쇠18/s, 작은 상대 수직 속도(<0.08m/s) 감쇠12/s를 추가한다. 정지에서 강하고 이동·회전 시 연속 감소,3m/s 이상에서는 추가 감쇠0. 기존 Launch/충돌/Grab/기울기/높은 상대 속도 해제 조건을 유지하고 지원 타이머도 초기화한다. 위치 snap/강제0속도/freeze/parenting/강제Sleep 없음.
- 초기 동일 배치 비교(평균 선속도 / |수직속도| m/s / 각속도 rad/s):

| 배치 | 이전 | 이후 |
|---|---|---|
| Pan 수평 | 0.00006059 / 0.00003674 / 0.00014551 | 0.00005795 / 0.00003058 / 0.00010785 |
| Pan+Can | 0.00629258 / 0.00006288 / 0.00129606 | 0.00629393 / 0.00005927 / 0.00098981 |
| Pan2개 | 0.00005070 / 0.00002624 / 0.00012931 | 0.00005029 / 0.00001637 / 0.00009244 |

- 수평 Pan 수직 평균 약17%, 회전 약26% 감소. Pan+Can 선속도/변위는 개선되지 않았으므로 모든 진동이 제거됐다고 해석하지 않는다. 수평 최대 변위0.00006295→0.00004356m, Pan2개0.00011149→0.00015737m. 300측정 frame 중 자연Sleep0. 단독은Cart1개, 혼합은Cart+상품2개 접촉. 직진 수직peak0.12197→0.12306m/s로 거의 같고 직진/회전/정지 후 적재1개 유지.

### KING RAT 원인과 전투 흐름

- 수정 전 강한 hit 후3초에 Player 거리0.341m, PURSUIT, Charge cooldown996.42초(검사에서 공격을 억제하기 위한1000초 설정)로 밀착 추적이 재현됐다. 실제 기본 cooldown은8초다. 기존 모터는 마지막 Player 위치까지 접근하고 최소 정지 거리가 없었다. Stagger 종료는 SEEK_FOOD 다음 tick에 곧바로 PURSUIT가 되고, recoil 중에도 AI 판단/Charge 전이는 계속 실행됐다. 일반 overlap push도 매 frame 적용됐다.
- RECOIL/REPOSITION 상태를 기존 enum 끝에 추가해 기존 상태 index를 보존한다. 피격 시 Pursuit/Telegraph/Charge를 중단하고 recoil 이동만 우선한다. Strong hit은 기존 Stagger45피해/0.45초를 유지한다. 종료 후 목표 기억을 유지하면서 가까우면 Reposition, 거리가 충분하면 Pursuit, 기억이 없으면 Food/Zone으로 복귀한다.
- 공격 간격3.2m, Reposition3.5m/s, 진입 hysteresis0.25m, 피격 종료 후 Telegraph 유예0.35초. 가까울 때 뒤/옆으로 물러나고0.7m body probe로 막힌 뒤쪽 대신 측면을 선택한다.0.6초 진행이 없으면 측면 방향을 바꾼다. Charge 종료0.3초 Recovery도 같은 거리 재평가를 사용한다. 쿨다운 동안 보이는 Player의3.2m 이내로 계속 전진하지 않는다.
- 일반 overlap push는 Character별0.4초 간격, 한 번 최대0.3 impulse(기본0.2)로 제한한다. Recoil/Stagger/Reposition/ChargeRecovery/Downed에는 적용하지 않는다. Charge Hit Area의 피해30/Knockdown/한 Charge당1회는 별도 유지한다. 소화기 외력/상품 Damage 계산/Cart 밀착 반복 Damage는 변경하지 않았다.
- Roam3.6/Pursuit4.8/Charge7.5m/s, awareness22m, memory6초, recoil0.25초/최대4.5m/s, 기존 route/food/zone 흐름 유지. 간단한 측면 probe이며 모든 장애물로 둘러싸인 배치의 탈출을 보장하는 Full Navigation은 아니다.

### 검사 / 수동 확인 / Known Issues

- 신규 `prompt11_6_probe.gd`: 실제 적재와 피격 재현·비교. `prompt11_6_smoke.gd`: 적재5종, 주행/발사/Cart Bomb, 피격→거리 확보→Charge, 실제1초 동안 일반Push2~3회 제한/Downed 제외. `prompt11_6_extra_smoke.gd`: 실제 support timer, 가장자리 자유 낙하, 다른 얇은 축의 임의 상품, 약한 hit/연속 hit/뒤쪽 벽에서 측면 복구.
- 추가 임의 상품 검사에서 접촉 법선 좌표를 중복 변환한 구현 오류가 발견됐다. 0.45×0.35×0.06m 물체를90° 눕히면 backend의 `get_contact_local_normal`이 이미 약(0,1,0)을 반환하는데 body basis를 다시 곱해 지지 판정이 실패했다. 직접 반환값을 사용하도록 수정했다. `.godot/p116_extra_diagnostic.log`에 실패·회전·속도·접촉 법선 기록을 보존한다. Pan 정상 적재의 평균 접촉점4개, Pan+Can/두Pan8개, Pan+Watermelon5개이고 basket 접촉shape index는0(바닥)였다. 상시 정상지원300frame을 확인한다.
- 초기 전체 회귀0의 전진 벽 접촉,1의 투척4항목이 실패했다.1 로그의 Player yaw가 약0.9rad로 변해 투사체가 목표를 빗나간 입력 조건을 확인했다. 같은 검사/코드의 단독 재실행에서0은22개,1은48개 모두 통과했다. 물리 검사를 약화하거나 Player 입력 로직을 바꾸지 않았으며 초기 실패 로그를 보존한다.11.3의 군중 통과 검사도3초 뒤 최종 변위가2m 미만으로 실패했다. Charge 뒤 새 Reposition/Pursuit로 되돌아올 수 있으므로 관찰 중 최대 실제 변위가2m 초과인지 검사하도록 수정했다. 충돌 통과 기준을 낮춘 것이 아니라 공격 종료 후 다른 상태의 최종 위치와 통과 진행을 분리했으며 재검사135개 통과.
- 최종 Prompt0~11.5 전체2,386개, 신규 기본30/추가11개 합계2,427개 통과. 선택 로그 목록은 `.godot/p116_results.txt`. 초기 회귀 `p116_reg_<stage>.log`,0/1/11.3은 `p116_final_<stage>.log`, 최종 cargo/추적 회귀11.5 및11.5_extra와 신규11.6/11.6_extra는 `p116_verified_<stage>.log`를 사용한다. 실패한 실행도 별도로 남기며 중복 재실행은 PASS 합계에 넣지 않는다. 임포트 `p116_verified_import.log`, Main headless7,200ticks/120초 `p116_verified_main.log`, 실제 창 Main600ticks `p116_main_window.log` 모두 오류0.
- 120초 Chaos 검사: Tourist12명 중11명 실제 상품 방문, Queue peak10, Pursuit5,490ticks, Rat 총 이동100.05m, 관찰용 Player HP10000→9550. Thief/Drunk/Lost Family/Fire/Spill/Cart/상품 Scatter 중 사업과 전투가 계속 진행했다. 렌더 `p115_chaos.png`도 확인했다(기존 검사 스크립트의 출력 파일명). 공격성이나 수동 손맛의 최종 판정은 사용자 조작으로 확인한다.
- 수동 확인: Pan 평평하게5~10초, Pan+Can/Milk/Watermelon, 주행/회전/급정지와 불안정 edge/Cart Bomb. I→U OFF→R 후 Pan/Watermelon/TV 투척, 아주 가까운 거리, Charge 직후 쿨다운, 연속hit, Tourist/Fire/Spill 혼합에서 공격 박자를 확인한다. 자동 측정으로 수동 전투 손맛이 검증됐다고 표시하지 않는다.
- 유지: **NPC Knockdown Mesh / Collider mismatch**, **Cart Contact Repeated Damage**, **Day Reset Prototype**, **Monster / Character visual overlap Final Combat Polish**. 극단적인 과적·비정상 걸침의 흔들림/낙하는 허용된다. 고정 aisle route 및 간단한 Reposition의 복잡 장애물 한계는 남는다.

## Prompt 11.5 — Cart Cargo Stability / KING RAT Pursuit / Hit Recoil

2026-10-25 구현·자동 검증 완료. 기존 회귀 **2,294 + 신규92 = 2,386 PASS / 0 FAIL**, 최종 선택 로그 Script/엔진 오류0. 작업 시작 Git 상태는 clean이었으며 변경은 uncommitted로 유지한다. Weapon/새 Boss/네트워크/인벤토리 슬롯/NavMesh는 추가하지 않았다.

### Cart 원인 재현 / 안정화

- 수정 전 빈 Cart, Can9개, Watermelon/Microwave/TV 단독, 혼합11개를 실제로 적재해 정지3초+측정3초, 직진3초, 회전1.5초, 급정지1.5초를 비교했다. `.godot/p115_before.log`에 결과를 보존한다. Can9개의 정지 수직 속도 평균0.0307/최대0.0726m/s, 주행 최대0.881m/s, 혼합11개 주행 최대1.031m/s였다. 이 배치에서는 심한 이탈까지 재현되지는 않았다.
- 차체는 `_integrate_forces`에서 handle 목표 속도/회전을 빠르게 보정하고 바구니 material bounce0.05를 사용하지만, 기존 적재물에는 상대 운동 감쇠가 없었다. 반복 바구니/상품 접촉 후 미세 속도가 남는 것을 확인했다. 차체/상품 질량 이중 합산이나 상품을 Parent/Static으로 고정한 구조는 아니었다. 이번 수정은 질량·바구니 충돌·운전 가속을 바꾸지 않고 이 낮은 상대 운동을 제한적으로 감쇠한다.
- 추가 16kg 적재 프레임 추적에서 차체가 먼저6m/s에 도달하고 저마찰 바구니의 상품은 뒤처진 뒤, 뒤벽 접촉 순간 차체 수직 속도 약0.7m/s와 수평 감속이 발생했다. 안정화 OFF에서도 같은 현상이 한 프레임 늦게 나타났다. 이는 정상 급가속의 물리 산개 가능성을 남기는 동작이며, 상시 velocity 고정으로 제거하지 않는다.
- 기존 LoadVolume의 실제 cargo 목록을 재사용한다. GrabbableBody가 WeakRef로 지원 Cart를 참조하고 자기 `_integrate_forces`에서 soft assist를 받는다. Cart 이동+회전에 따른 접촉 위치 속도에 대한 상대 속도만 감쇠하며 위치 snap/centering/parenting/freeze는 없다.
- 기본값: 상대 속도 상한1.6m/s, linear damping4/s(수직 절반), angular damping5/s, 보정 가속 상한3m/s². local x±0.72/z±0.82/y≤1.12 내부만 적용해 rim/상단 과적은 붙잡지 않는다. 원래 `linear_damp`/`angular_damp`를 덮어쓰지 않아 Carry/Spill과 복원 충돌이 없다.
- Grab, armed throw, basket 이탈, Cart Launch4초, impact spill1초, 급가감속24m/s² 초과, 회전2.5rad/s 초과, 약20° 이상 기울기, 상대 속도/회전 초과에서 해제한다. 급가감속/기울기 후0.45초 재진입 유예. Cart 속도0.15m/s 이상이면 sleeping cargo를 깨워 지원 물체 이동에 반응하게 한다.
- 카트 밖으로 나온 상품 Label을 무조건 show하던 기존 경로도 11.4의 `show_debug_label` 정책으로 복구한다. 상품 가격 정보가 산개 후 다시 상시 나타나지 않게 한다.
- 최종 동일 배치 Can9개 ON/OFF 비교: 정지 수직 속도 평균0.0647→0.0129m/s, 최대0.0780→0.0269m/s. 정지·직진·회전/급정지 후9개 유지. 주행 peak는0.486→0.972m/s여서 모든 주행 충격이 감소했다고 주장하지 않는다. 혼합11개는11개 유지, 정지 평균0.000394/주행 peak0.968m/s. 단독 Watermelon/Microwave/TV도 적재 유지.
- 4초 정지에서 모든 적재물이 자연 Sleep에 들어가지는 않았다. 별도 Sleep→Wake 검사는 출발 직전 물체를 Sleep 상태로 두고 실제 카트 이동 시 깨어나1m 이상 이동하는지 확인한다. 정지 중 강제 Sleep 후 한 프레임 유지라는 추가 전제는 실제 접촉이 이미 Wake시켜 실패했으므로 제거했고, 이동/물리 유지 검사는 그대로 통과했다(`p115_sleep_fixture_initial.log`). 보정이 자연 Sleep을 일정 시간 내 보장한다는 의미는 아니다.

### KING RAT 위협 / 경로

- Roam3.6m/s, Food search42m, 구역 순회는 유지한다. Player awareness22m, Pursuit4.8m/s, target memory6초를 추가했다. 실제 LOS에서 인지하고, 시야가 끊기면 마지막으로 본 위치를 추적한다. 숨은 Player의 현재 위치를 계속 읽어 추적하지 않는다. Downed Player는 추적 대상에서 제외한다.
- 우선순위: Defeated → Stagger → Charge/짧은 Recovery → Pursuit → Food/Zone. Charge7.5m/s, Telegraph0.65초, cooldown8초, 피해30 및 고정 방향 Hit Area는 유지한다. Charge가 끝나면0.3초 Recovery 후 기억이 남으면 Pursuit 재개.
- `RatAisleRoute`는 기존 Main/Cross/Service aisle 좌표에 고정 교차점을 둔 작은 그래프다. Boss 크기 sweep으로 통과 가능한 인접 간선 및 출발/도착 연결만 사용한다. Customer/기존 Food 경로를 전면 교체하지 않는다. 0.8초 간격 재탐색, 실제 진행이1초 막히면4초 동안 바닥 상품도 경로 장애물에 포함한다. Cart/World는 항상 경로 장애물이며 실제 solid collision도 유지한다.
- 첫 우회 검사 실패: 경로 sweep 반경0.68m가 실제 몸체0.65m보다 커 벽 접촉 위치에서 모든 출발 경로를 막았다. sweep 반경0.63m/중심높이0.65m로 작은 접촉 여유를 두었다. 같은 선반 우회 재검사에서 측면 통로로 이동해 Player와0.33m까지 접근했다.
- 고정 TV 검사에서는0.8초 경로 갱신이1초 정체 timer를 매번 지우는 오류를 추가 발견했다. 경로 갱신과 정체 timer를 분리해, 실제 진행 또는 정체 대응 시에만 초기화한다. 중간 실패 로그는 보존한다.

### Combat Recoil

- 기존 상품/Cart `receive_impact(amount, impulse)`의 피해 계산과 충격 방향을 그대로 사용한다. `min(4.5, damage×0.055 + impulse.length()/18×0.25)`m/s의 수평 recoil을0.25초 감쇠 적용한다. 해당 짧은 시간에는 AI 이동 대신 recoil이 우선하며 외력과 합친 실제 수평 속도도4.5m/s로 제한한다.
- Recoil은 누적하지 않고0.3초 cooldown을 둔다. 기존 strong hit threshold45 / Stagger0.45초를 유지한다. Damage만 받거나 일반 Character overlap/소화기 `receive_impulse`만 받으면 recoil을 시작하지 않는다. Cart 반복 접촉 Damage 자체는 의도대로 수정하지 않는다.
- 실제 Full Throw 측정 recoil: Bread0.226, Can0.238, Watermelon0.457, Frying Pan0.673, Microwave1.309, TV2.972m/s. 값은 원래 price/weight/charge/impact 결과를 사용하며 Boss 전용 상품 Damage는 만들지 않는다.
- 실제 움직이는 Boss에 Can2개 Loaded Cart를 발사한 최종 검사: 차체 피해27.21, 총 피해33.81, Boss 이동3.18m, recoil speed1.747m/s. 별도 충돌 분리 검사에서도 Cart 본체+상품2개 총3회 Hit 및 실제 산개를 확인했다. 물리 이동 거리는 충돌 배치에 따라 달라진다.

### 검사 / 수동 확인 / Known Issues

- 신규 `prompt11_5_cargo_probe.gd`는 수정 전/후 측정용, `prompt11_5_smoke.gd`는 적재/추적/실제 상품 충돌58개, `prompt11_5_extra_smoke.gd`는 고정 상품 우회/Charge miss/경사/극단 recoil/실제 이동 Boss Cart 충돌26개, `prompt11_5_chaos_smoke.gd`는 통합8개를 검사한다.
- Prompt3.1 최초 회귀1건 실패: 0.3초의 마지막 한 프레임 속도가 위 뒤벽 접촉에 걸려2.76m/s였다. 실제로는 같은0.3초 안에 이미6m/s에 도달했고, 보정 OFF도 다음 프레임에2.74m/s로 감속했다. 검사 의도인 '0.3초 이내4.5m/s 초과 도달'을 구간 내 최대 속도로 검사하도록 바꿨다. 입력 반응/회전/정지/전복/질량/Launch 기준은 유지했고 재검사 통과했다. `.godot/p115_handling_trace.log`, `p115_final_prompt11_5_handling_trace.log`, `p115_reg_3_1.log`를 보존한다.
- 초기 통합 검사에서는 같은 프레임 특수 손님 생성으로 입구 안전 검사에 걸려 Drunk 생성이 거부됐다. Debug 입력처럼1.5초 간격으로 생성했다. 초기60초에서는 Tourist12명 모두 상품 방문했지만 Queue0명이었고, 관찰을120초로 늘려 다품목 구매 후 Queue 진입까지 검사했다. 최종: Tourist12/12 상품 방문, peak Queue9, pursuit5,610ticks, Rat 총 경로173.41m, Charge로 관찰 Player HP10000→9550. 긴 관찰 동안 solo Day Failure로 종료되지 않도록 테스트에서만 HP를 높였다. Thief/Drunk/Lost Family/Fire/Spill/Cart/상품 Scatter 동시 존재를 확인했다. 초기 로그 `p115_chaos_initial.log`를 보존한다.
- 최종 Prompt0~11.4 회귀 **2,294 PASS**, Prompt11.5 **92 PASS**, 합계 **2,386 PASS / 0 FAIL**. 선택 로그 목록/개수는 `.godot/p115_results.txt`. 초기 실행은 `p115_reg_<stage>.log`, 재검사 및 후반 회귀는 `p115_final_prompt<stage>_smoke.log`, 통합은 `p115_chaos.log`를 사용한다. 진단 전용 중복 실행은 합계에 넣지 않는다. 고정 상품 우회 재검사에서도 Player 기억을 유지한 채 TV 뒤 z16.05까지 진행했다.
- 최종 코드 import(`p115_final_import.log`), Main headless7,200ticks/120초 simulation(`p115_main120.log`), 실제 창 Main600ticks(`p115_main_window.log`) 모두 종료코드0 및 Script/엔진 오류0. 통합 렌더 `p115_chaos.png`도 직접 확인했다. 자동 검사 결과는 모든 배치의 무정체나 수동 조작감을 보장하지 않는다.
- 자동 검사와 별도로 F5→I 후 Can/Milk/Watermelon/TV/Microwave 혼합 적재, 직진/회전/U턴/급정지/Cart Bomb을 수동 확인한다. I→U OFF→R 후 시야 진입, 선반 뒤 이동, 장거리 도주, 상품별 Throw와 Loaded Cart 충격을 비교한다. Rush/Thief/Fire/Spill 동시 손맛은 수동 평가가 남는다.
- 유지: NPC Knockdown Mesh/Collider mismatch, Cart Contact Repeated Damage, Day Reset Prototype, Monster/Character visual overlap Final Combat Polish. 과적·rim에 걸린 상품·급회전·강한 충돌에서는 여전히 흔들림/이탈이 가능하며 cargo physics는 Final Polish에서 추가 평가한다. 고정 aisle 그래프는 Full Navigation이 아니므로 여러 물체가 모든 통로를 막은 경우의 경로 보장은 없다.

## Prompt 11.4 — Floor Product Recovery / Rat Mobility / Dense Racks / Aim Info

2026-10-23 구현·자동 검증 완료. 기존 회귀 1,830 + 신규 464 = 총 **2,294 PASS / 0 FAIL**, 최종 선택 로그 Script/엔진 오류0. 작업 시작 Git 상태는 clean이었으며 변경은 uncommitted로 유지한다. Weapon/새 Boss/Network/Navigation 전면 교체는 구현하지 않았다.

### 바닥 상품 정체 재현과 복구

- 수정 전 실제 BasicCustomer 모터로 좁은 통로의 고정 TV를 향해 이동시켰다. 8초 뒤 z=1.55에 막혀 목적지에 도달하지 못했다(`.godot/p114_before.log`). 기존 CartRecovery는 ShoppingCart만 감지하여 상품에는 우회/복구가 없었다.
- 별도 작은 `ProductRecovery`를 BasicCustomer 및 CarryableCharacter에 연결한다. Basic 파생 Thief/Parent/Accident/Dangerous/Tourist와 Drunk/Child가 같은 정책을 사용하며 Monster에는 적용하지 않는다. CartRecovery는 수정하지 않는다.
- 낮은 높이의 전방 probe1.25m, push force12, side speed0.9m/s, side delay0.2초, stuck threshold1.1초, pair clear distance1.8m. 작은 상품은 실제 impulse로 먼저 밀며, 목표 방향 progress가 `max(0.15m/s, 명령 속도×0.3)`보다 낮을 때만 안정된 한쪽으로 비킨다. SHOP/Queue는 보정0.4, Drunk는0.6 배율이다.
- 낮게 넘어진 TV 모서리는 capsule과 접촉해도 전방 ray 아래에 있을 수 있어, probe가 놓칠 때 실제 slide/contact 목록도 확인한다. 인접한 상품 사이에서 감지가 바뀌어도 상품별 timer/side를1.5초 동안 보존한다. 실제 pass-through pair는 거리가 벌어지거나 물체 상태가 바뀔 때 별도로 해제한다.
- 높이/회전을 고려해 바닥 상품만 처리하고, 진열대 상품·들고 있는 상품/도구·빠른 투사체는 복구 대상에서 제외한다. Child의 capsule 높이도 고려한다. AI가 Shelf 재고를 미리 밀어내지 않도록 한다.
- 동일 장애물에 계속 막힐 때 해당 Human/Product 양방향 pair만 잠시 통과한다. 여러 pair를 별도로 관리하고 거리 이탈·Grab·대상 제거·NPC 제거/Carry 시 복구한다. WeakRef와 tree_exiting cleanup으로 삭제된 physics RID를 남기지 않는다.

### KING RAT Mobility

- 기본 move_speed2.4→3.6m/s, search radius24→42m. Player 이동5m/s와 Charge7.5m/s/telegraph0.65초/cooldown8초는 유지한다.
- 여섯 구역의 빈 통로 진입점: (0,6), (26,6), (26,27), (0,27), (-26,27), (-26,6). 같은 구역2개 섭취 또는18초 체류 또는 주변 상품 없음이면 다음 구역으로 이동한다. 실제 진입한 구역을 visited_zones에 기록한다.
- 구역 도착 후 그 구역의 실제 상품을 우선 탐색한다. 이동 중에도 기존 Player 근접 Charge가 작동하고 이후 구역 이동을 재개한다. 같은 측면 통로는 중앙을 왕복하지 않으며, 기존 고정 StoreRoutes와2.5초 stuck recovery를 유지한다.
- 실제 모터 자유 이동 비교: 5초12.00→18.00m, 10초24.00→36.00m. 60초 자동 관찰에서 Produce/Cookware→Household→Electronics 3구역, 총 이동176.59m, 실제 상품 손실330을 기록했다. 이 coverage 검사는 Player Charge를 억제한 이동 관찰이며 이후 근접 Charge를 별도 확인했다. 복잡한 장애물 길찾기를 해결한 것은 아니다.

### Shelf Density / Signage / UI

- 바닥72×36m 및 Rack footprint/통로는 유지한다. 다단 Rack3→13개, 3단1→6개. Pantry/Snacks/Drinks/Household의 기존 island 위에15개 Tier Section을 추가한다. 큰 상품 Display는 유지한다.
- 전체 Stock Section41→56개, Auto Stock198→318개. 각 단은 실제 deck/Area/slot을 가지며 같은 Rack의 Shopping Point 예약을 공유한다. 반복 facing과 기존 물리 상품을 사용한다. 배송 안전 상한256→400으로 조정하여 전체 진열 상태에서도 소량 배송을 허용한다.
- 전체 진열 직후4초 검사에서318개 생성,286개 Sleep, 최고 속도 약0.053m/s였다. 상품은 Static으로 전환하지 않는다. 순간 FPS/다양한 PC 성능을 보장하는 수치는 아니다.
- Shelf edge의 작은 Label3D에는 상품 이름만 표시한다. Zone Category Sign은 유지하고, 상시 Stock Count/Price/Weight 표시는 제거한다.
- 판매 상품의 World 상세 Label은 기본 OFF, Inspector `show_debug_label`로 선택 표시한다. 소화기 용량/도구 이름과 Customer Purchase Icon은 유지한다.
- PlayerInteraction의 기존 Grab Candidate ray 결과를 crosshair 색과 ProductInfo UI가 함께 사용한다. 별도 Hover ray를 만들지 않는다. 조준한 판매 상품의 실제 instance Name/Price/Weight 및 Catalog Food Heal만 화면 중앙 아래에 표시한다. 대상 변경/삭제/비상품/잡은 상태/입력 제한 상태에서는 갱신 또는 Hide한다.

### 검사 이력

- 최초 신규 실행의 probe origin 타입 추론 Parse Error를 Vector3 명시로 수정했다. 이후 실행에서 상단 deck과 Detergent 하단 상품 간섭으로4개 slot이 비어 Household 상단을0.75m offset으로 높였다.
- Godot에서 지원하지 않는 `%g` 숫자 서식은 `%.0f`/`%.1f`로 수정했다. 렌더 확인에서 깨진 장식 기호도 제거해 `Name / $Price | Weight kg / +Heal HP`로 표시한다.
- 초기 coverage에서 앞쪽 Shelf Row 위의 구역 진입점이 막혀, 진입점을 z27 횡단 통로로 이동했다. 최초 실패 로그는 보존한다.
- Prompt11 회귀의4개 연쇄 실패는 빈 매장에서 이미 구역 이동을 시작한 Rat를 테스트가 임의 위치로 옮기고 상품을 추가한 뒤, 이전 구역 경로가 남은 fixture에서 발생했다. 배치 위치 기준으로 SEEK_FOOD/구역을 초기화하되 실제 이동→Eat→Stock/Loss/OOS 계약은 그대로 검사하여 재통과했다.
- 추가 Scatter 검사에서 처음에는 취객이4초에1.98m 전진해 고정2m 경계에 못 미쳤다. 관찰을 전체 Scatter 통과로 확장하자 낮은 TV 접촉을 ray가 놓치는 현상과 인접 상품 전환 때 timer가 초기화되는 실제 문제를 확인했다. 실제 접촉 보조 및 상품별 encounter timer를 추가한 뒤 약11.8초에 z26→33.03으로 통과,4개 pair recovery를 수행했다. 진행률 기준만 높인 중간 수정은 충분하지 않았으며 해당 실패 로그도 보존한다.
- 신규 핵심 검사: light Can 실제 push/예외0, 연속 pinned TV2개 통과 및 pair복구, held tool 제외, 실제5/10초 이동, 전체 Tier 실재고/Name Tag/318개 top-up, Sleep, 실제 ray 기반 Bread/TV 정보와 대상 삭제 Hide, 60초 구역 방문/실제 Eat/근접 Charge.
- 최종 결과: Prompt0~11.3 회귀 **1,830 PASS**, 신규 핵심450 + flow13 + 최초 재현 재검사1 = **464 PASS**, 합계 **2,294 PASS / 0 FAIL**. Section/상품 증가에 따라 기존 동적 반복 검사의 수도 증가했다. 전체 회귀 실행 후 마지막 ProductRecovery 보완에 대해서는 신규 핵심/flow 및 Prompt5/6.1/10.2를 다시 실행했다.
- 최종 로그: 기존 `.godot/p114_reg_<stage>.log`, Prompt11은 `p114_final_11.log`, 재검사5/6.1/10.2는 `p114_tuned_<stage>.log`, 신규는 `p114_tuned_11_4.log`/`p114_flow_pairs.log`/`p114_reproduce_after.log`. 선택 결과 목록은 `.godot/p114_results.txt`. 모든 최종 선택 로그 종료코드0, SCRIPT ERROR/ERROR/FAIL 없음. 중간 실패 로그는 위 이력과 함께 보존한다.
- 최종 코드 import, Main headless 7,200 physics ticks(120초 simulation), 실제 창 Main600 ticks 모두 종료코드0/오류0. 로그는 `p114_tuned_import.log`, `p114_tuned_main120.log`, `p114_tuned_main_window.log`.
- 실제 318개 재고+바닥 상품12개+Tourist12명 시나리오에서10명 이상의 목적지 진행을 확인했고, Thief Scatter 통과 및 Drunk 약11.8초 통과도 확인했다. 정상 Rush에서는 다중 Shelf/Queue 진행과 예약 일관성을 검사했다. 자동 시나리오 통과가 모든 물체 배치의 무정체나 수동 조작감까지 보장하지는 않는다.
- 실제 렌더로 Product Aim UI와 Pantry3단 진열/Name Tag를 확인했다(`p114_aim.png`, `p114_rack.png`, `p114_store.png`). 전체 Chaos의 손맛과 가독성 최종 평가는 아래 수동 검사로 남긴다.

### 수동 검사 / Known Issues

- F5→I: 318개 다단 진열, 가까이서 Tag와 상품 시야 확인. 상품 조준 시 상세 UI, 다른 곳을 보면 Hide. 하/중/상단 Grab/수동 재진열을 확인한다.
- 통로에 Can/TV/Mop을 놓고 U ON/B/T/K로 일반 손님·Rush·Thief·Drunk 진행 확인. Player가 들고 있는 도구/날아오는 상품 및 Cart 충돌은 계속 실제 물리로 작동해야 한다.
- I→U OFF→R 후1분 관찰: 구역 이동, 상품 섭취, 일반 이동과 Charge 차이를 확인한다. Cart+상품 Scatter+Rush+Fire+Spill 동시 손맛은 수동 확인이 남는다.
- NPC Knockdown Mesh/Collider mismatch, Cart Contact Repeated Damage, Day Reset Prototype은 유지한다. KING RAT simple pathing/구역 진입 막힘 및 Monster/Character visual overlap은 Final Combat Polish에서 재평가한다.

## Prompt 11.3 — Large Supermarket / Multi-tier / Character Hit Area

2026-10-21 구현·자동 검증 완료. **기존 회귀1,590 + 신규120 = 총1,710 PASS / 0 FAIL**, 최종 선택 로그 Script/엔진 오류0. 변경은 uncommitted다. Prompt 11.2 이후 사용자가 Food Self Heal 및 Shelf 뒤 Player 탈출의 정상 동작을 확인했다. 아래 11.2의 미재현 설명은 당시 조사 이력으로 보존한다.

### 매장 규모와 이동

- Store 바닥 36×18=648㎡ → **72×36=2,592㎡, 정확히 4배**. Floor mesh/collision 면적 비교이며 진열대가 차지하는 면적을 뺀 순수 보행 면적은 아니다. Scene scale과 Player 속도5/Jump4.5는 변경하지 않았다.
- Store x±36, z0..36. 중앙은 후면 기존11.2m, 전면 진열 구간 최소9.2m 폭이다. 전면 Shelf 중심 x±6/±13/±21/±29, z24/30. 섹션 간 측면 최소4.2m, 두 row 간 횡단4.6m. 뒤쪽과 양끝을 통해 여러 순환 경로로 복귀한다.
- Backroom3m+Loading3m, 중앙 Rear Door5m를 유지한다. Truck→rear store 거리 증가 없이 주요 기존 재고가 가까이 있다. 앞쪽 먼 재고에는 카트 사용 가치가 생긴다.
- Entrance x[-6,0], z36, 폭6m. Bus와 외부 apron도 z+18 이동. Checkout은 (11,34) 한 개, Queue는 x1..11/z32.6 및31.35로 중앙 배송·전투 축 오른쪽에 둔다.
- Produce, Drinks/Dairy, Snacks/Pantry, Household, Cookware, Electronics, Checkout, Rear Delivery를 표지와 바닥 띠로 구분한다. 19개 기본 Stock section(호환 Appliance 포함)+22개 분산 section, 총41개로 밀도를 확보한다. 다단 section 4개는 기본 rack과 공간을 공유한다. 분산 section 용량은 최대4개로 제한해 빈 공간과 과도한 물리 상품 증가를 함께 줄인다.

### Catalog / 실제 크기

기존9개 id와 Appliance 호환을 유지한다. 새 상품도 기존 GrabbableBody/Definition/price damage/weight throw/Cart/Fire/Thief/Consume를 사용한다. 크기는 x×y×z(m), Tier는 주 진열대 기준이며 분산 진열은 독립 낮은 display다.

| 상품 | 가격 | kg | 크기 | Food / Heal | 가연성 | 주 진열 |
| --- | ---: | ---: | --- | --- | --- | --- |
| Can | 5 | 1 | .28×.32×.28 | 아니오 | 예 | Pantry 1단 |
| Bread | 10 | .5 | .50×.22×.24 | 예 /15 | 예 | Bread 1단 |
| Milk | 15 | 1.5 | .25×.48×.25 | 예 /20 | 아니오 | Dairy 1단 |
| Glass Drink | 25 | 1.2 | .20×.45×.20 | 아니오 | 아니오 | Drinks display |
| Detergent | 30 | 2.5 | .36×.50×.30 | 아니오 | 예 | Household display |
| Watermelon | 50 | 4 | .56×.56×.56 | 예 /30 | 아니오 | Produce display |
| Frying Pan | 120 | 3 | .85×.12×.48 | 아니오 | 아니오 | Cookware display |
| Microwave | 300 | 7 | .68×.50×.45 | 아니오 | 예 | Electronics display |
| TV | 800 | 10 | 1.05×.75×.25 | 아니오 | 예 | Electronics display |
| Chips | 8 | .3 | .35×.30×.16 | 예 /8 | 예 | Pantry 3단 |
| Instant Noodles | 6 | .4 | .30×.18×.25 | 예 /10 | 예 | Pantry 2단 |
| Cereal | 18 | .8 | .30×.40×.20 | 예 /12 | 예 | Bread 2단 |
| Juice | 20 | 1.5 | .24×.38×.24 | 예 /15 | 아니오 | Dairy 2단 |
| Cooking Oil | 35 | 2 | .28×.40×.25 | 아니오 | 예 | Pantry display |
| Shampoo | 25 | 1 | .20×.35×.20 | 아니오 | 예 | Household display |
| Toilet Paper | 22 | 1.8 | .65×.45×.40 | 아니오 | 예 | Household display |
| Rice Bag | 45 | 5 | .55×.30×.40 | 예 /25 | 예 | Pantry display |
| Vacuum Cleaner | 250 | 6 | .60×.75×.50 | 아니오 | 예 | Electronics display |

### 다단 진열 / 업무 연결

- ProductDefinition의 `rack_base_name`, `shelf_tier_height`, `shelf_tier_clearance`로 주 진열 rack과 단을 지정한다. 각 단은 기존 StockShelf를 재사용하며 독립 deck collision/Area/실제 재고/용량을 가진다. 같은 rack의 단들은 floor-level Shopping Point 예약을 공유한다.
- Pantry deck 상면 .65/1.20/1.60m, Bread/Dairy .65/1.30m. 상단 deck 깊이 .9m, 후방 offset .25m, slot 열 간격 .5m로 하단 상품을 바라보는 시야와 상단 접근을 확보한다. 기둥은 x±1.34m에 두어 넓은 Bread와 겹치지 않는다. 상단 높이는 점프 없이 Carry로 접근하는 범위이며 실제 손맛은 수동 확인한다.
- 상품 종류와 해당 단의 높이·영역·속도·소유권이 모두 맞아야 정상 Stock이다. 잘못 놓은 상품이나 overstock은 삭제/정렬하지 않는다. AutoStock은 단 높이를 더한 실제 slot에 부족분만 생성하고 겹친 slot은 건너뛴다.
- Customer는 같은 예약·Basket·Scan/Pay를 사용한다. `shopping_focus`와 얼굴 표지가 구매 단을 향하며 몸 capsule은 upright다. Thief/Fire/Monster도 각 section의 실제 상품을 재사용한다.
- Delivery는 한 번에 기존처럼 3종×2개만 공급하고 이후 배송에서 18종을 순환한다. 전체 물리 상품 안전 상한은96→256으로 조정해 전체 자동 진열만으로 배송이 중단되지 않도록 했다.

### Monster / Character 이동과 공격 분리

- 원인: 기존 Rat mask193와 Human/Player mask의 Monster bit가 capsule 간 hard blocking을 만들고, Charge 피해도 `move_and_slide` 충돌 결과에 의존했다. 군중이 둘러싼 상태에서는 이동과 공격 판정이 서로 묶여 있었다.
- KingRat의 Human mask를 제거하고, Human 및 등록된 PlayerHealth 소유 body와 **상호 pair exception**을 둔다. Player/World/Product가 layer1을 공유하므로 layer1을 통째로 제거하지 않는다. 새로 등장하는 사람도 처리하고 카트에는 exception을 적용하지 않는다. WeakRef registry와 `tree_exiting`으로 대상 제거 전에 양쪽 예외를 해제하며, Rat 제거 때도 정리한다. Human↔Human Soft Separation 및 Human CartRecovery는 유지한다.
- `CharacterHitArea`: capsule radius1m/height1.8m, layer0, mask1|64. Charge 중에는 기존 `_charge_hit`의 charge별 id set으로 한 대상1회만 피해30/KD/push를 준다. 일반 겹침은 impulse12×delta의 약한 분리만 적용하며 HP를 깎지 않는다. Carry 중인 NPC와 Defeated boss는 접촉 반응을 생략한다.
- Player는 공통 `apply_external_impulse`를 받으며 속도2m/s clamp/감쇠5로 bounded 보정을 합산한다. 기본 이동·점프·Backward Fall은 유지한다. Rat은 HumanSeparation에 들어가지 않는다.
- World/Shelf/Cart/Product/Tools의 solid collision과 기존 상품·Cart Damage/Cart Bomb은 유지한다. 이 방식은 시각적 겹침을 완전히 없애는 crowd navigation이 아니다.
- Rat Food 범위는 Store x±35.5/z0..36, 검색반경24m의 가까운 실제 상품이다. 중앙/횡단 waypoint와2.5초 stuck retarget를 사용한다. 외곽 후면 섹션(abs x>20,z<21)은 x±26 서비스 통로와 z1/21 중 짧은 횡단점을 경유한다. 같은 서비스 통로의 목표는 중앙까지 왕복하지 않는다. Customer/Thief/Rat가 이 작은 고정 통로 그래프를 공유한다. Shopping Point 대기도 해당 Shelf 인근이며 대기점까지 같은 경유 경로를 사용한다.
- Eat는 수평1.9m 및 높이2.25m 제한과 실제 LOS를 검사한다. 대상 단 높이에 맞춘 bite ray로 높은 상품도 실제 제거/Loss 경로에 들어간다. 멀리 있는 상품만 남으면 search 반경 밖이라 먹이 탐색이 멈출 수 있고, 복잡한 장애물 우회는 여전히 한계다.

### 검증 이력

- 최초 신규 script 실행은 테스트 결과 변수명 오타로 Parse Error가 발생했다. `failures`로 수정한 뒤 초기 신규 검사에서 Catalog/물리 진열/공유 예약/top-up/Area Charge를 통과했다. 초기 로그를 보존한다.
- Prompt3의 초기 실패5건: 분산 진열대도 모두 동일 재고라고 가정한 옛 fixture와 상단 deck에 가려진 하단 Grab이 원인이었다. 배치한 주 진열대만 기대 재고를 검사하고, 실제 하단 Grab 시야를 확보하도록 상단 deck 깊이를 줄였다. 기존 공급 fixture는 상품 크기와 tier 높이를 사용해 deck 사이에 생성한다.
- 매장 확대에 따라 계산대/Queue/Entrance 좌표 및 이동 대기 상한을 갱신한다. 기존 판매·예약·Loss·물리 계약은 유지한다. Catalog/전체 진열 수/배송 순환 검사는18종 및 분산 section 기준으로 확장한다.
- 추가 발견·수정: 손님 despawn 후 Rat가 매 프레임 `get_collision_exceptions`로 삭제된 물리 RID를 조회하면서 엔진 오류가 발생했다. WeakRef registry 및 제거 전 양방향 cleanup으로 수정하고 despawn 회귀를 추가했다. 상단 기둥에 걸린 Bread 4개 슬롯도 기둥 위치 조정으로 수정했다.
- 초기 대량 검사에서 기존 직선 접근 sweep은 새 서비스 통로 경유와 맞지 않아 실패했다. 실제 StoreRoutes의 모든 구간을 capsule sweep하도록 바꾸고, Shelf 뒤 탈출도 연결된 통로로 검사한다. 한 Rush 대기점은 직선으로 걸어가다 선반에 막혀 동일 경유 경로를 적용했다.
- 퇴장 거리 증가에 따른 가족/Spill 접근 대기 상한과, 입구 이동 후 취객 제거 fixture를 조정했다. 수동 이동시킨 Thief fixture는 이동 후 실제 위치에서 경로를 다시 계산한다. Rush 손실 검사는 helper의60초 대신 실제 기본 Patience25초를 명시한다. Prompt10.1의 기대 수량 변수 범위 오타로 발생한 초기 Parse Error도 수정했다.
- 최종 결과: Prompt0~11.2 **1,590 PASS**, Prompt11.3 **120 PASS**, 총 **1,710 PASS / 0 FAIL**. Catalog/section 수가 늘어 기존 동적 반복 검사의 개수도 증가했다. 모든 최종 검사 종료코드0, `SCRIPT ERROR:`/`ERROR:`/`FAIL:` 없음.
- 실제 12명 Rush: 11명 상품 방문, 9명 Queue 도달, 15종 구매 경로 분산, peak Queue9, 예약 중복 없이 이벤트 종료. 별도12명 Rush+Cart2+Rat 검사에서 Rat 이동3.67m, 강제 Cart/Rat/Human 교차에서 Rat 이동1.58m 및 Human 경로 완료. 이는 자동 시나리오의 결과이며 모든 배치에서 혼잡이 사라진다는 보장은 아니다.
- 신규 검사는 41개 section 총198개 실제 자동 진열 및 재입력0/부족분1, 세 단 실제 ray Grab, 하·중·상단 실제 Pickup→Scan→Pay, 새 Food5종 실제 G, 상단 Rat Eat/Loss, 이전 hard blocking 재현과 동일 경로 해제, Area Charge 피해/KD1회, 일반 접촉 HP 불변, NPC despawn pair cleanup을 포함한다.
- 최종 로그 선택: `.godot/p113_reg_<stage>.log` 기본, stage3/4/5/5_1/6_1/7_1/8_1/9/10/10_1은 `p113_retry_<stage>.log`, 10_2/11_2/11_3은 `p113_final_<stage>.log`. 최초 실패 로그는 삭제하지 않았다. 실행은 문서의 Godot 경로에서 `--path . --fixed-fps 60 --script res://tests/prompt<stage>_smoke.gd`로 순차 수행했다.
- 최종 import(`p113_final_import.log`), Main headless7,200 ticks/120 simulated seconds(`p113_main120.log`), Main 창600 ticks(`p113_main_window.log`) 모두 종료코드0/오류0. `.godot/p113_store.png` 실제 렌더에서 확장 floor/진열 island/구역 색상/전면·후면 연결을 확인했다. `git diff --check` 정상. 4인 조작감, 큰 매장의 이동 시간, Loaded Cart 회전 및 시각적 겹침은 아래 수동 검사가 남는다.

### 수동 확인 / Known Issues

- F5→I로 전체 진열, 하/중/상단 Grab/수동 재진열/잘못된 단 확인. U OFF→B로 Rush, R로 KING RAT를 함께 실행한다. Player+Human+Rat 겹침에서도 진행되는지, Charge 피해/KD와 Cart Bomb은 유지되는지 확인한다.
- 각 Shelf 뒤/side/cross aisle 순환, Loaded Cart U턴, 후면 직결 배송, 전면 Queue, G Food Heal 및 동료 Revive 테스트 scene을 확인한다. 실제4인 네트워크 검증은 아직 아니다.
- **NPC Knockdown Mesh/Collider mismatch**, **Cart Contact Repeated Damage**는 의도적으로 유지한다. Cart rubbing 손맛/악용 여부는 Final Combat/Physics에서 수동 평가한다.
- Day Reset은 Prototype이다. Monster navigation은 단순 waypoint/stuck recovery이며, 이번 변경 후 사람과 겹쳐 보이는 정도는 Final Combat Polish에서 재검토한다. Weapon/새 Boss/Multiplayer/Round Director는 구현하지 않는다.

## Prompt 11.2 — Combat Store / Food Input / Recovery Routes

2026-10-20 구현·자동 검증 완료. **기존1,208 + 신규108 = 총1,316 PASS**, 최종 Script/실행 오류0. 단, 사용자 보고의 싱글플레이 G 실패 원인은 아래와 같이 미확정이며 수동 조건 재확인이 필요하다. 시작 시 있던 `project.godot` G/H 키 에디터 직렬화 변경은 보존했다. commit/amend/reset/push하지 않았으며 변경 사항은 uncommitted다.

### Food 입력 조사와 수정 범위

- 수정 전 Main Player의 실제 ray Grab → `InputEventKey(KEY_G)` 경로에서 Bread/Milk/Watermelon은 각각 HP50→65/70/80 및 실제 삭제에 성공했다. 따라서 사용자 보고의 **싱글플레이 Self Heal 실패 자체는 현재 작업 트리에서 재현되지 않았고 정확한 원인이 확정되지 않았다.** G 등록, Catalog is_food/heal_value, holder, TeamLife 등록은 정상이다. API만 호출하는 검사를 재현 증거로 사용하지 않았다.
- 별도로 재현한 분기 오류: 앞에 살아 있는 PlayerHealth 대상이 있으면 기존 입력 코드가 이를 `use_food`에 전달했고, 해당 메서드가 Downed가 아니라는 이유로 거부하면서 Self Heal까지 막았다. `.godot/p112_reproduce_normal.log`에 수정 전 실패를 보존한다. Main에 가짜 Player가 없는 점을 고려하면 이것을 신고 원인으로 단정할 수 없다.
- G를 Grab과 같은 물리 프레임 요청으로 처리한다. 유효한 가까운 Downed 동료 Feed가 성공하면 종료하고, 그 외에는 자기 자신에게 `use_food`를 시도한다. Self Heal에는 조준 조건이 없다. Full HP/Non-food/Downed/소유권/소비된 상품 차단과 중복 비용 방지는 기존 PlayerHealth가 담당한다. 이 변경은 입력 시점의 물리 조회를 한 경로로 모은 것이며, 미재현 실패의 확정 원인이라고 주장하지 않는다.
- 신규 검사는 실제 Main, 자동 진열 상품, ray Grab, 활성 Player motor, 물리 H/G 이벤트를 포함한다. Food별 회복량/실제 소비/소비 비용, Full HP/Non-food 보존, Alive 조준 대상 fallback, Downed 동료 우선순위를 검사한다.

### 공간과 동선

| 항목 | 기존 | 변경 |
| --- | --- | --- |
| Store floor | 30×12m, 360㎡ | 36×18m, 648㎡ (1.8배), 개별 geometry 재배치 |
| 중앙 전투 통로 | 중앙 3개 Shelf row | 좌우 내부 island 사이 11.2m, 중앙 x=0 배송/이동 축 |
| 측면 통로 | Shelf 끝과 외곽 상품이 인접 | 내부 island와 외곽 Shelf 사이 약4.9m |
| 내부 island 횡단 간격 | 단일 중앙 row | z=6/12 두 row 사이 약4.5m |
| 외곽 Shelf 사이 gap | 오른쪽 약0.3m | 왼쪽3.2m, 오른쪽 최소2.6m |
| 외벽 뒤 서비스 통로 | 외곽 Shelf 뒤 협소한 일부 공간 | 약3.1m, 양끝과 Shelf 사이 gap으로 복귀 |
| Rear door / backroom | 문5m, backroom3m+loading3m | 그대로 유지, 배송 이동 길이 증가 없음 |
| Entrance | 폭4m, z=12 | 폭6m, z=18 |
| Checkout | (5,10) | (11,16), 1개 유지 |
| Queue | 중앙 가로줄 | 전면 우측 9명×2줄, 1.25m 간격; x≥1, z=13.35/14.6 |

- 내부 Shelf: Can(-7,6), Watermelon(7,6), Frying Pan(-7,12), 호환 Appliance(7,12). 외곽: x=-14에 Bread/Milk/Glass Drink(z=3/9/15), x=14에 Detergent/Microwave/TV(z=3/8.4/14). 정규9종 및 기존 Appliance 호환, 물리 크기/가격/무게/용량은 유지한다. TV의 전면 Shopping Point 접근이 계산대와 겹치지 않도록 우측 끝 두 Shelf 간격을 조정했다.
- 모든 Shelf 뒤에는 보행 가능한 공간을 둔다. 외곽 뒤에서 Shelf 간 gap → 측면 통로 → 횡단 통로 → 중앙으로 복귀한다. Jump4.5는 변경하지 않았다. 좌우 각각 순환 동선이 있으며 긴 벽형 Shelf를 추가하지 않았다.
- `StoreRoutes.via_main`은 새 레이아웃의 고정 중앙 경유 waypoint만 제공한다. 기존 Customer/Thief/Monster 모터·예약·충돌·stuck recovery를 대체하지 않는다. KING RAT는 상품 검색 범위만 x±17.5/z0..18로 확장하고 기존 Eat/Charge/Damage를 유지한다. Knockback 후 임의 위치에서의 복잡한 장애물 경로는 여전히 한계다.
- Bus 외부 apron/정차/승객 입구는 전면 이동에 맞춰 z+6. 취객 Spawn/Removal은 Entrance 기준이다. Lost Family 근거리 생성 범위는 유지한다. Fire는 기존 실제 Floor ray/Area 방식이므로 고정 Store bounds 변경이 필요하지 않았다. Auto Stock slot은 Shelf local 좌표여서 새 Shelf transform을 따른다.
- Human↔Human, Human↔Cart, Monster 충돌 mask 및 CartRecovery는 변경하지 않았다. Queue 첫 지점이 TV Shelf와 겹쳤던 초기 배치를 회귀 검사에서 발견해 수정했다.

### 검증 이력 / 수동 재평가

- 샌드박스 실행의 인증서/편집기 설정 저장 오류 후 정상 사용자 환경으로 임포트·검사를 재실행했다. 최초 로그도 보존한다.
- 기존 테스트의 계산대 위치는 station 상대 좌표, 취객 배송은 새 Entrance, Shelf 충돌은 새 Shelf 위치에 맞춘다. 늘어난 실제 쇼핑 이동 거리 때문에 Checkout 대기 상한을 조정한다. 물리/판매/예약 검증 조건은 삭제하지 않는다.
- Prompt4 최초 재검사는 두 종류를 사는 첫 손님보다 단일 상품의 두 번째 손님이 먼저 도착해 기존 fixture의 생성순서=도착순서 가정이 깨졌다. 두 사람의 예약은 동시에 유지하고, 첫 사람이 실제 Checkout에 도착한 뒤 두 번째 motor를 재개해 FIFO의 실제 도착순서를 통제한다. 이 실패에서 후속 검사까지 연쇄 실패 및 freed-reference 오류가 발생해 해당 실행만 종료했고 로그를 보존한다. Gameplay의 Queue 규칙은 바꾸지 않는다.
- 신규 경로 검사의 첫3건 실패는 중앙에 배치된 이동 가능한 소화기와 충돌한 결과였다. 해당 소화기를 계산대 옆(16,17)에 배치해 초기 통로를 비우고 동일한 capsule sweep 조건으로 재검사했다.
- 최종 자동 검사: Prompt0~11.1 **1,208 PASS**, Prompt11.2 **108 PASS**, 합계 **1,316 PASS / 0 FAIL**. 정상 사용자 환경의 최종 임포트, Main headless7,200 ticks(120 simulated seconds), Main 창600 ticks 모두 종료코드0 및 SCRIPT ERROR/ERROR:0. `git diff --check` 정상.
- 최종 로그: 기존 항목은 `.godot/p112_reg_<stage>.log`; 재검사0/5/5_2/7_1/10_1 및 신규11_2는 `.godot/p112_verified_<stage>.log`; Prompt4는 `.godot/p112_final_4.log`. 실행 로그는 `p112_final_import.log`, `p112_main_120s.log`, `p112_main_window.log`. 초기 실패 로그는 덮어쓰지 않았다. Prompt0 초기 입력6건 실패는 코드 변경 없이 별도 실행에서22건 모두 통과했다.
- 신규 결과: 모든 Shelf 뒤 capsule 보행 탈출 경로,30 Shopping Point 접근, 중앙/측면 cart-sized sweep,18명 논리 Queue 좌표,55개 실제 Auto Stock 및 top-up, 실제 재고 Grab/H/G 입력 검사가 통과했다. 12명 Rush가8종 Shelf를 방문하고 Queue4명에 도달했다. Boss+카트2대 공존10초에서 Boss가6.79m 진행하고 Queue9명까지 형성됐다. 강제 Cart/Rat/Human 교차10초에서는 Human이 목적지에 도달했고 Boss가2.36m 이동했다. 이 한 사례를 정체 발생 빈도 전체의 증명으로 해석하지 않는다.
- 창 렌더 개요 `.godot/p112_store.png`를 확인했다. 넓은 중앙 공간, 좌우 Shelf island/뒤 서비스 통로, 전면 우측 Queue 및 외부 Bus가 표시된다. 기존 개발 HUD와 계산 패널 일부 겹침은 UI polish 범위이며 이번 작업에서 수정하지 않았다.
- 수동: F5→I→H→Food Grab→G, Full HP/TV G 확인. 각 Shelf 뒤에서 점프 없이 탈출. Loaded Cart U턴/90도/Launch, I→U OFF→R의 Dodge, I→U OFF→B의 Rush, 이어 R/T/K/L/O/P로 복합 상황 확인.
- Cart+KING RAT+Human 맞물림 발생 빈도와 실제 4인 조작감은 수동 재평가가 필요하다. 단순 공간 검사/단일 시뮬레이션 통과만으로 모든 정체가 해소되었다고 판단하지 않는다.
- 기존 Final TODO 유지: **NPC Knockdown Mesh/Collider mismatch**, **Cart Contact Repeated Damage**(Boss rubbing 수동 판단), **Day Reset은 Prototype**, **KING RAT 단순 Pathing**. 근접 상품 Label의 Downed 시야 가림 등 기존 외형 polish도 유지한다. Weapon/Multiplayer/새 Boss/Full Day Reset은 구현하지 않는다.

### 변경 파일 역할

- `player_interaction.gd`: 물리 프레임 Consume 요청 및 Downed 동료 우선/Self fallback.
- `mart_graybox.gd`, `mart_graybox.tscn`, `data/products/*.tres`: 개별 Floor/Wall/Entrance/도구 위치와 Shelf island 배치. 상품 물리 수치는 그대로다.
- `store_routes.gd`: 고정 중앙 경유점. `basic_customer.gd`, `customer_manager.gd`, `thief_manager.gd`, `thief_customer.gd`, `king_rat.gd`: 새 Shelf/전면 좌표 및 검색 범위 연동. 전투/충돌 정책은 유지한다.
- `tourist_bus.gd`, `drunk_test_manager.gd`: 외부 정차/입장/퇴장 위치 연동.
- `tests/prompt11_2_smoke.gd`: 신규108검사. 기존 테스트의 계산대/진열대/출구/Spill/Cart fixture와 도착순서·이동 대기 상한을 새 배치에 맞췄다. 기존 assertion은 유지한다.
- `README.md`, `PROJECT_NOTES.md`: 조작/레이아웃/검증 이력과 미확정 사항 기록. AGENTS/Skill은 변경하지 않았다.

## Prompt 11.1 — Cart Recovery / Player Health / Food Revive

2026-10-19 구현 및 자동 검증 완료. **기존1,151 + 신규57 = 총1,208 PASS**, 최종 실패/실행 오류0. 시작 시 `project.godot`의 R 입력 Editor 직렬화 변경이 이미 있었고 보존했다. commit/amend/reset/push하지 않고 모든 변경을 uncommitted로 유지한다. 실제 군중/전투 조작감은 수동 테스트가 필요하다.

### Cart 원인 / 복구

- 기존 Human motor는 Cart 충돌 후 같은 목적지 방향을 계속 요구했다. Human Separation은 다른 Human만 다루므로 Cart 장애물에는 복구가 없었다.
- 같은 좁은 통로 fixture에서 기존 직진 motor는 z≈0.479에서 600 ticks 후에도 막혔다. 수정 motor는 열린 통로에서 측면 x≈-1.22로 우회해 z>4.5 도달, 좁은 통로에서는 쌍별 통과 후 z>4.5 도달 및 양쪽 exception 제거를 확인했다. 실제 Customer AI motor의 목적지 진행도 검증했다.
- `CartRecovery`는 Human 전용 작은 Node다. 진행 방향2.2m에 capsule 폭을 고려한3개 probe로 Cart를 찾는다. 벽 너머 Cart를 탐지하지 않는다. 양쪽1.5m 여유를 비교해 encounter 동안 고정된 side를 선택한다.
- side_speed1.5, 최대 desired speed의80% 보정. Queue/Checkout/SHOP은0.4, Drunk0.6, 나머지 이동1.0. 목표 이동과 외부 push는 유지한다. Basic 기반 Tourist/Accident/Dangerous/Thief/Parent와 Carryable 기반 Drunk/Child Follow에 연결했다. 들기/Cart 위 적재/Knockdown/Fire는 기존 동작을 우선한다.
- 실제 forward progress가0.15m/s 미만인 정체2초 후 해당 NPC–Cart 양쪽에만 exception.2.5m 이상 떨어지면 복구하며 Cart 삭제/Character 삭제/Carry 시작에서도 정리한다. World/Player/다른Cart/Product/Monster mask는 변경하지 않았다. KING RAT에는 적용하지 않는다.
- 가까이 이어진 Cart 두 대는 각 쌍을 독립적으로 처리한다. 이미 통과 중인 Cart를 probe에서 제외해 다음 Cart도 감지하며, 첫 Cart 예외를 유지한 채 둘째 Cart 복구가 가능하다. 좁은 통로의 두 Cart 통과 및 모든 exception 복구 검사도 통과했다.

### Player Health / Downed

- `PlayerHealth`: Player별 max/current_health, is_downed, receive_damage(amount, source), heal, enter_downed, revive, reset_for_day, changed/downed/restored 신호. 기본HP100.
- KING RAT charge_damage30. 기존 돌진별 hit set으로 동일 대상1회이며 NPC에는 HP를 추가하지 않았다. Player Damage 후 기존 Knockdown. 이미 Downed면 추가 피해 없음.
- 공통 Knockdown에 persistent_down을 추가했다. HP0이면 started 신호로 held Product/Character/Cart/Charge/Tool을 해제하고 FALLING→DOWN에서 멈춘다. 기존 Spill Knockdown의 시간/연출/면역은 변경하지 않았다.
- DOWNED 중 이동/Jump/Grab/Throw/Tool/Checkout 제한, Mouse Look 유지. 기존 upright Capsule과 Backward Camera pose 유지. revive하면 기존0.4초 STANDING_UP 후 입력 복귀. Day reset은 pose/velocity/시작 transform/Head look을 복구한다.

### 음식 / 부활 / 통계

- ProductDefinition에 is_food(false), heal_value(0). Bread15/Milk20/Watermelon30만 음식으로 설정했다. 다른 가격·무게·물리 설정은 유지한다.
- `G = consume_item`. 자신 회복은 Full HP 차단. 들고 있는 실제 상품 ownership, food flag, 유효성 검사 후 회복/노드 삭제. `consumed_product_value += 실제 price`1회. queued 상태로 Customer/Fire/Thief/Boss의 기존 소비 검증과 연결된다.
- `PlayerHealth.use_food(food, target)`는 살아 있고 조작 가능한 제공자, 같은 Team에 등록된 Downed 대상, 거리2m, World LOS를 검증한다. G 입력은 Camera Ray로 대상 PlayerHealth를 고른다. 동료는 heal_value×2(30/40/60)로 부활하며 다른 Alive Player가 반드시 필요하다.
- Self revive/비식품/거리 초과/벽 너머/전원 Downed 이후 부활은 차단한다. 네트워크 동기화 없음.
- `tests/food_revive_test.tscn` F6 전용으로 테스트 동료를 생성한다. 실제 PlayerHealth·Knockdown과 물리 Body를 사용하며 Main에는 가짜 Player를 두지 않는다.

### Team / Day prototype

- `TeamLifeManager`가 PlayerHealth 목록을 등록하고 Alive 수를 센다. 한 명이라도 Alive면 계속 영업. 마지막 Downed 순간 day_failed signal을1회 발생시키고 feeding 허용을 즉시 닫는다.
- 기본2초 DAY FAILED 표시 후 current_day+1, 모든 등록 Player Full HP/시작 위치/정상 pose. 보스는 통계 보상 없이 정리하고 각 시작점3m 안의 Fire/Spill을 정리한다. 기타 Inventory/매출/Customer/모든 Event를 reset하지 않는다. 전체 Round Director/Day economy persistence는 미구현이다.
- 작은 HUD에 HP/ALIVE/DAY/FOOD 표시. `H = debug_damage_player`로30 HP 감소. G/H는 기존 입력과 중복 없음. R/I/U/B 및 특수 Spawn은 기존대로다.

### 검사 이력 / 결과

- 초기 sandbox import는 인증서/AppData editor settings 접근 오류. 정상 사용자 환경에서 재실행했다. 최초 Main compile의 Cart probe origin 타입 추론 오류는 Vector3 명시로 수정했다.
- 첫 신규 검사15실패: 부활 fixture가 기존 Checkout 위치여서 Counter에 LOS가 막혔다. 열린 후면 통로로 옮기고 실제 G Ray 입력으로 검증했다. 첫 부활 실패로 뒤의 Downed/Day 단계가 연쇄 실패했으며 실패 로그를 보존했다. 수정 재검사0실패. 벽·거리 차단과 실제 Customer motor, HP0 Character/Cart release 검사를 보강한 신규55개도 통과했다.
- 연속 Cart 검사2개 보강 후 신규57 PASS. 첫 전체 회귀의 일부 입력 검사에서36개 실패가 발생했다. Cart/Checkout/Fire 이동/Thief 포획 실패 로그에는 mouse=0(잠금 해제), blocked=false가 기록됐고 Full Charge 캡처에서도 조준점/Charge UI가 숨겨져 있었다. 실패 로그는 `.godot/p111_before_focus_*.log`에 보존했다.
- 테스트 시작 시 Window.grab_focus를 한 번 요청하도록 보강했다. 실행 중 자동 재잠금이나 포커스 상실 무시는 하지 않는다. Prompt0 yaw는 시작 각도0 가정 대신 입력 전후 회전량과 sensitivity를 정확히 비교한다. 공통 실패 진단에 mouse/yaw/held/charge/blocked를 기록한다. 입력 검사 재검증 결과는 아래 최종 합계에 반영한다.
- 최종 결과: Prompt0~11 1,151 PASS + Prompt11.1 57 PASS = 1,208 PASS. 최종 `p111_verified_*.log`에 SCRIPT ERROR/ERROR:/FAIL:0, 모든 검사 종료코드0. 신규 연속 Cart 변경 뒤 관련 Checkout/Drunk/Family/Fire/Thief도 재검증했다. Import, Main 7,200 physics ticks(60Hz 기준120초 시뮬레이션), F6 부활 Scene 180 ticks 모두 정상 종료, 오류/경고0.
- 최종 로그 `.godot/p111_verified_*.log`, `.godot/p111_import_final.log`, `.godot/p111_main.log`, `.godot/p111_manual_scene.log`. `.godot/p111_downed.png`에서 실제 DOWNED HP0/ALIVE1 HUD와 기상하지 않는 자세를 확인했다. 입력 상태 관련 실패를 코드 성공으로 숨기지 않고 최초 로그와 재검증 이력을 함께 보존한다.

### 수동 / Known Issues

1. I→U OFF→B, 통로에 Cart: 열린 공간 우회/좁은 공간 임시 통과/충돌 복구, Queue 위치 복귀 및 Thief/Drunk/Family 확인.
2. I→R, Charge 피격:30HP 감소·Backward Fall. H로도 감소 가능. 세 음식 Grab→G 회복과 Full HP/비식품 차단 확인.
3. 단독 Player HP0: DAY FAILED→2초 후 다음 날 Full HP/정상 조작/Spawn, KING RAT 제거 확인.
4. `tests/food_revive_test.tscn` F6: 후면에 있는 음식 Grab→2m 안 Downed 동료 겨냥→G. Bread30/Milk40/Watermelon60HP 부활 확인.
5. Boss/Rush/Thief/Fire/Spill/Cart와 병행하여 각 업무·음식 경쟁·Stock 감소를 확인한다. 실제 Full Chaos 조작감은 수동 판단 대상.
- NPC Knockdown Mesh / Collider mismatch 유지. Player Downed Capsule도 upright이며 최종 물리 표현은 별도 검토.
- Cart Contact Repeated Damage 유지. 실제 보스전에서의 재미/악용 여부는 Final Combat/Physics에서 결정.
- 기존 바닥 경계 고속 Cart 도약 및 보스 단순 waypoint 길찾기 한계 유지.
- DOWNED 캡처에서 바로 앞에 떨어진 상품의 큰 Graybox Label이 시야를 가리는 현상을 관측했다. 상품 근접 Label 표시 조정은 추후 Visual Polish 검토 사항이다.
- Day Reset은 Player 중심 Prototype이다. 전체 경제/재고/이벤트 리셋과 네트워크 Multiplayer는 없다.
- 수동 검증 정상 후 Prompt12 근접 도구/무기 progression 준비. 정식 Weapon은 아직 추가하지 않았다.

## Prompt 11 — Combat Foundation / KING RAT

2026-10-17 구현 및 자동 검증 완료. **기존1,089 + 신규62 = 총1,151 PASS**, 최종 실패/실행 오류0. 시작 Git은 clean(Prompt10.2 사용자 정리 완료)이었다. 이번 작업은 commit/amend/reset/push하지 않고 uncommitted로 유지한다. 무기/Player Health/보상 경제/다른 보스는 구현하지 않는다. 전투 손맛과 Cart rubbing 평가는 수동 테스트가 필요하다.

### Monster / 공통 Combat Target

- `scripts/combat/combat_target.gd`: 작은 CharacterBody3D 기반. max_health/current_health, receive_damage, receive_impulse, 기존 `receive_impact(damage, impulse)` 및 PhysicsPush의 `apply_external_impulse`를 제공한다. damaged/defeated signal과 중복 처치 방지, 제한된 external_velocity를 가진다.
- Monster는 기존 예약 layer8(bit128)을 실제 사용한다. Human 그룹/Soft Separation에 등록하지 않는다. Monster mask193(기존 World/Player/Physics1 + Human64 + Monster128), Human mask129 유지. Player/Cart/Product/Tool mask에128을 추가했다. 선택 Ray·소화기·화재 LOS도 Monster를 장애물/외력 대상으로 인식한다.
- 공통 접촉 Area에서 움직이는 RigidBody의 접근 속도·질량을 읽어 제한된 Push를 받는다. Mop/툴에 피해 공식을 새로 붙이지 않는다. 외부 Push는 AI desired velocity와 합산한다. World/선반 Capsule 충돌은 유지한다.
- 기존 상품·Cart는 이미 receive_impact 호출 인터페이스가 있으므로 피해 공식과 충돌 코드를 바꾸지 않았다. 상품은 기존 price/Charge 피해, impact_min_speed 게이트, weight 기반 속도·impulse를 사용한다. Cart는 기존 impact speed×effective mass 및 상한, cargo의 개별 arm_cart_impact 경로를 그대로 사용한다.

### KING RAT / 먹기 / 손실

- `scripts/combat/king_rat.gd`, `scenes/combat/king_rat.tscn`: Capsule 충돌, 타원형 body/head, 귀·눈·꼬리 primitive. 외부 에셋 없음.
- SPAWN(0.5초) → SEEK_FOOD → MOVE_TO_FOOD → EAT → SEEK_FOOD. TELEGRAPH → CHARGE, 강한 피격 STAGGER, DEFEATED 상태도 있다.
- 실제 grabbable 그룹에서 product_type이 있는 Store 내부 상품만 선택한다. 도구/들고 있는 상품/삭제 예정/sold/stolen/broken/boss_eaten은 제외한다. 가장 가까운 유효 상품을 선택하며 별도 가짜 상품이나 인벤토리는 없다.
- Shelf 상품은 기존 Shelf 앞 Shopping Point 위치를 접근 목표로 사용하되 고객 예약을 점유하지 않는다. 기존 중앙 통로 z=3.1을 통해 접근하며 바닥 상품도 지원한다. 전체 Navigation을 새로 만들지 않았다. 목표 변경/삭제/Grab은 재탐색, 2.5초 진행 없음 또는 접근 경로 소진 시 해당 상품을 5초 피하고 재탐색한다.
- 돌진 후 중앙 Shelf 앞쪽(z>6.7, |x|<7.4)에 남으면 z=7.7 → 가까운 측면 x=±7.6 → z=3.1 순서로 우회한다. 모든 목표가 같은 선반 벽에 재접근하는 상황을 피하는 Graybox 한정 경로이며 기존 Store나 NPC 경로를 바꾸지 않는다. 실제 예약 상품 먹기 검사 시작 위치를 앞쪽으로 바꿔 이 복귀 경로도 검증한다.
- 먹기에는 거리1.9m + World 가시성 + 최종 유효성 검사가 필요하다. 1.5초 먹기 완료 시 `boss_eaten` 표시 후 실제 노드를 즉시 queue_free하고 Shelf.refresh_stock을 호출한다. queued 플래그가 같은 tick의 판매/절도/화재 검증도 무효화한다. 예약 손님은 기존 OOS로 연결된다.
- `boss_product_loss_value += 실제 price`만 기록한다. Sales/unpaid/stolen/fire/broken ledger에 중복 손실을 넣지 않는다. 먹다가 Player가 옮기거나 다른 시스템이 상품을 소비하면 먹기를 취소한다.

### Charge / Stagger / Defeat / UI

- Player가 7m 이내이고 cooldown이 끝나면 0.65초 주황색·`!` 준비 후 0.8초 동안7.5m/s 돌진한다. 방향은 준비 시작 시 고정되어 Player가 옆으로 이동하면 추적하지 않는다. 초기 cooldown4초, 이후8초다.
- 실제 slide collision에 닿은 Player/Human의 기존 Knockdown.try_start를 사용한다. 돌진당 대상1회, 기존 immunity/Carry 예외를 존중한다. Player의 held Drop/Cart release/charge cancel/Backward Fall은 공통 Knockdown signal로 그대로 발생한다. NPC 작업 상태는 별도로 변경하지 않는다.
- Cart/상품은 기존 PhysicsPush로 밀 수 있으며 선반을 파괴하거나 통과하지 않는다. Monster 자체에는 Spill Knockdown/Fire Panic/화재 HP를 추가하지 않았다.
- 한 hit45 이상이면0.45초 Stagger. 흰색 hit flash0.18초와 피해 숫자 표시. max_health300, HP0이면 처치 signal1회,1.5초 몸 기울임 후 Despawn.
- `king_rat_manager.gd`: R debug action, 동시1마리(처치 연출 포함), 안전 공간 query와 Player3m 이상 거리 확인. 후면 후보 (0,0.02,2),(-4,0.02,2),(4,0.02,2) 순서로 시도한다. 막히면 생성하지 않는다. UI는 보스 활성 중 KING RAT/HP만 표시하고 평시에는 숨긴다. 작은 [R] 통계는 계속 표시한다.
- `bosses_defeated`: defeated signal당+1. `boss_product_loss_value`: 실제 먹은 값 누적. 보상/Unlock 없음. 어떤 Boss Mode도 없으며 U 선택·Customer·Checkout·Delivery·Rush·특수 Event를 멈추지 않는다.

### 실제 조절값

| 위치 | 변수 | 기본값 |
| --- | --- | --- |
| CombatTarget | max_health / target_mass / max_push_speed | 300 / 18 / 5m/s |
| CombatTarget | push_drag | 3.0(비례 감쇠) |
| KingRat | move_speed / eat_time / eat_reach | 2.4m/s / 1.5초 / 1.9m |
| KingRat | charge_cooldown / charge_range | 8초 / 7m |
| KingRat | telegraph_time / charge_speed / charge_duration | 0.65초 / 7.5m/s / 0.8초 |
| KingRat | charge_push | 3.5 |
| KingRat | stagger_threshold / stagger_time | 45 / 0.45초 |
| KingRat | defeat_time / stuck_time | 1.5초 / 2.5초 |

### 파일 / 검사 이력

- 신규 CombatTarget/KingRat/KingRatManager 스크립트(+UID), king_rat.tscn, tests/prompt11_smoke.gd(+UID).
- 수정 Mart에 Bosses 연결, project.godot R/Monster 레이어 이름, Player/Grabbable/Cart/Interaction/Extinguisher/Fire LOS 마스크, README/이 문서. 기존 prompt2_1의 정확한 Cart mask 기대값에 Monster bit를 추가했고 World/Player/Human 보존 계약은 그대로다.
- 샌드박스 import에서 사용자 AppData Godot 설정 저장 권한 오류가 발생해 정상 사용자 권한으로 재실행했다. 프로젝트 parse 오류와 구분한다. 초기 로그 보존.
- 최초 신규 검사에서 Cart 관련3건 실패. Backroom z=-1.5에서 Store의 보스 z=2로 발사하면 바닥 경계에서 카트가 튀어 보스 위로 지나갔다. 로그에서 cart y≈2.22/0.98까지 상승한 실제 궤적을 확인했다. 직접 보스 충돌 검사만 같은 Store 바닥 z=1→4.3으로 분리했다. Cart 물리/피해/바닥 구조는 수정하지 않았다.
- 다음 분리 검사에서 실제 Cart 피해는 정상이나, cargo가 흩어진 뒤 현재 effective_mass로 피해를 다시 계산하던 검사1건이 실패했다. 충돌 당시 last_impact_mass를 사용해 원래 공식을 검증하도록 수정했다. 빈 카트 약25.55 피해, 적재 Cart 약27.71 + Can2개 개별 명중을 관측했다. 물리 산포가 있는 관측값이며 고정 밸런스 수치가 아니다.
- `.godot/p11_boss.png` 실제 렌더에서 보스 외형/HP/UI를 확인했다. 최초 통합3실패와 원인 분리 로그, 수정 후 통합0실패 로그를 보존한다. 수동 전투 손맛/Cart rubbing 평가를 자동 통과라고 보고하지 않는다.
- 최종 자동 회귀: Prompt0~10.2 1,089 PASS, Prompt11 62 PASS, 합계1,151 PASS. 모든 검사 종료코드0, 최종 로그 SCRIPT ERROR/ERROR:/FAIL: 0. 실제 창 입력 검사는 순차 실행했다. 최종 import와 Main 7,200 physics ticks(60Hz 기준120초 시뮬레이션)도 종료코드0, 오류/경고0.
- 최종 로그: `.godot/p11_verified_*.log`, `.godot/p11_import_final.log`, `.godot/p11_main.log`. 신규 검사에서 실제 상품 명중, 빈/적재 Cart 명중 및 개별 cargo 피해, 선반 앞쪽 우회 후 예약 상품 먹기, 중복 손실 방지, Player/Human 돌진 피격·회복, 옆 회피, 소화기 실제 분사 Push, 동시 Bus/Thief 진행을 확인했다. 전체 Full Chaos 조작감은 수동 확인 대상으로 남긴다.
- 보강한 실제 소화기 검사에서1건 실패: 분사 impulse/18kg의 tick 증가량보다 기존 고정 감속3m/s²가 커 작은 외력이 매번0이 되었다. 보스 외력 감속을 exp(-push_drag×delta) 비례 감쇠로 수정해 작은 지속 외력도 반응하도록 했다. 실패 로그 `.godot/p11_before_drag_fix.log`를 보존하고 최종 재검사62 PASS에서 실제 분사 이동/HP 불변을 확인했다.

### 수동 테스트 / Known Issues / 다음 단계

1. F5 → I → U OFF → R: HP/안전 Spawn/여러 실제 Shelf 및 바닥 상품 먹기/Stock 감소/BOSS LOSS 확인. 목표 상품 Grab 및 삭제 시 재탐색 확인.
2. Bread/Can/Watermelon/Pan/Microwave/TV의 Tap/Full Charge 피해와 거리 비교. 빈 Cart 및 Loaded Cart Full Charge로 본체+산개 상품 명중과 Stagger 확인.
3. 준비 `!`를 보고 옆으로 회피, 일부러 피격해 Drop/Backward Fall/회복 확인. NPC 피격 후 Shopping/Thief Escape/Family Exit 복귀 확인.
4. 소화기 F Push와 Mop 접촉 확인. R active 중 U/B/K/L/O/P/T·Delivery·Checkout을 병행한다.
5. 처치1회 통계/HP숨김/1.5초 후 제거/다시 R 확인. 기존 상품을 전투에 쓰는 재미와 가격·무게별 유효성은 사용자 수동 판단 대상이다.
- **NPC Knockdown Mesh / Collider mismatch** 유지.
- **Cart Contact Repeated Damage** 유지. KING RAT에 카트를 비빌 때 재미있는 기술인지 과도한 exploit인지는 **수동 테스트 필요**, 이번에는 수정하지 않았다.
- **바닥 경계 고속 Cart 도약**: 초기 보스 검사에서 실제 관측. 경계에서 튀면 공격이 빗나갈 수 있다. 이번 Prompt에서는 기존 바닥/카트 물리 변경 범위를 늘리지 않았다. Final Physics에서 동선/전투 조작감과 함께 확인한다.
- 보스는 통로 waypoint+재탐색 수준이며 완전한 길찾기는 아니다. 물리 장애물로 막힌 특정 상품은 잠시 피하며, 모든 길이 막힌 경우 플레이어의 환경 정리가 필요할 수 있다.
- 수동 검증 정상 후 Prompt12 근접 도구/무기 기반 확장 준비. 이번에는 전용 무기를 구현하지 않는다.

## Prompt 10.2 — Human NPC Soft Separation / Crowd Flow

2026-10-17 구현 및 자동 검증 완료. **기존1,058 + 신규31 = 총1,089 PASS**, 최종 실패/실행 오류0. 시작 Git은 clean(Prompt10.1은 사용자에 의해 정리된 상태)이었다. 변경은 uncommitted이며 commit/amend/reset/push하지 않았다. 실제 군중 조작감은 아래 수동 절차로 확인한다.

### 재현 원인 / 충돌 정책

- 기존 BasicCustomer/CarryableCharacter와 모든 World/Player/상품/Cart가 기본 layer 1을 공유했다. BasicCustomer의 move_and_slide가 NPC Capsule에 막히고, 목표 이동을 매 tick 다시 시도했다. 기존 분리는 manager.customers만 대상으로 0.85m 이내 반발을 제한 없이 합산해 Human 전체를 다루지 못했다.
- 수정 전 실물 교차 재현에서 두 손님은 x=-0.317701/+0.317701에서 정지하고 180 physics ticks 후에도 지나가지 못했다. `.godot/p102_baseline.log`에 실패 기록을 보존한다.
- 기존 레이어를 전면 재배치하지 않고 **layer7(bit64)=Human NPC**, **layer8(bit128)=Future Monster**를 추가했다. Human body는 layer64/mask129(기존 물리1 + 미래Monster128)다. Human↔Human은 양쪽 mask 모두 제외한다. Player/Cart/Product/Tool은 기존 layer1을 유지하고 mask에64를 더한다. Monster는 구현하지 않았으며 향후 layer128/body mask64로 상호 충돌 가능하다.
- Grab Ray, Fire/Spill Area, Drunk ExitRemoval 영역, 소화기/화재 LOS도 Human 감지를 보존한다. Shelf Stock/Cart cargo 감지는 상품 대상이므로 기존 mask1을 유지한다. 바닥 생성 Ray는 기존 World 대상으로 유지한다.
- 가족의 기존 재회 시 쌍방 예외는 호환성을 위해 그대로 두었다. 이제 일반 Human 정책상 중복이지만 새 NPC마다 예외를 추가하는 구조로 Crowd 정책을 구현한 것은 아니다. Follow Offset/퇴장 정리/재회 판정은 유지한다.

### 공통 Soft Separation / 상태별 적용

- 신규 `scripts/systems/human_separation.gd` Resource. `human_npcs` 그룹 중 자기 자신·삭제 예정·Carry 중 NPC를 제외하고 수평 근거리만 계산한다. 높이 차 1.5m 이상은 제외한다. 10~20명 규모의 단순 그룹 거리 검사이며 Navigation/RVO/ORCA를 추가하지 않는다.
- 기본값: radius1.1m, personal_space0.8m, strength1.5, max_separation_speed0.65m/s, side_bias0.35. 거리 감소에 따라 반발이 커지고 최종 속도 벡터를 clamp한다. 반대 방향 보정은 목표 속도의15%까지만 허용해 전진 의도를 보존한다. 물리적 겹침을 막기 위한 강제 위치 이동은 없다.
- 정면 상대에는 자기 진행 방향의 오른쪽 보정을 사용한다. 서로 반대 방향으로 걷는 두 NPC는 반대 월드 방향으로 비킨다. 매 frame random 선택 없음. 정확히 같은 위치의 반발 방향은 instance_id 순서로 고정한다.
- Basic/Tourist/Accident/Dangerous 이동1.0, Queue/Checkout0.35, SHOP/EVENT_WAIT0. 목표 0.5m 이내에서는 거리 비례로 보정을 줄여 waypoint/Queue 도착을 방해하지 않는다. Shopping Point 예약·해제·retry와 논리 Queue spacing은 기존 그대로다.
- Thief0.4, Drunk0.6. LostParent0.35(Queue 보정과 별도), LostChild 대기/Follow0.25이며 Follow 목표에 가까울수록 감소한다. Drunk의 wobble은 유지한다.
- Carry/Cart 지지 상태의 캐릭터에는 분리 이동을 적용하지 않는다. FireReaction/Knockdown 중에는 기존 조기 반환/물리 적분 경로를 우선한다. Basic의 external push는 AI+separation 뒤에 합산하고, Carryable의 외부 impulse 반응 시간은 기존 우선순위를 유지한다.

### 변경 파일 / 검사 계약

- `human_separation.gd`(+UID): 공통 레이어 및 Steering 설정.
- `basic_customer.gd`, `carryable_character.gd`, `drunk_customer.gd`, `lost_child.gd`, `lost_parent.gd`, `thief_customer.gd`: 기존 motor에 공통 보정 연결.
- Player/Grabbable/ShoppingCart/Interaction: Human 충돌·선택 마스크. Fire/Spill/Drunk 제거 영역 및 Fire/Extinguisher Ray: 감지 유지. `project.godot`: 레이어 이름.
- `tests/prompt10_2_smoke.gd`(+UID): 재현·모든 Human 타입 매트릭스·반경/반발/clamp/진행 보장/교차/Carry 제외/World·Player 충돌/실제12명 Rush 검사.
- 기존 2.1/6.1/6.2의 mask==1 검사는 확장 마스크 또는 World bit 유지로 변경했다. 6.1의 예외 없음 설명을 이제 충돌 있음으로 오해하지 않도록 갱신했다. 물리 World 및 Player/Cart 검사는 유지한다. 기존 검사를 삭제하지 않았다.
- Store Layout/AutoStock/Catalog/새 Event는 변경하지 않는다.

### 검증 결과

- 수정 전 교차 재현은 예상대로 1 FAIL. 수정 후 같은 180tick에서 x=+5.000001/-5.000001까지 지나갔다. Steering을 켠 별도 정면 교차·반경 밖0·근거리 반발·18명 밀집 clamp·방향 진행 보장·모든8종 Human 매트릭스·World/Player 양방향 test_move도 통과했다.
- 신규 첫 통합 실행 및 최종 재검사 모두 **31 PASS / failures0**. 실제 버스12명 모두 Shelf 방문 및 Queue 진입, 방문9종, 최대Queue12명. 중복 실제 상품 예약 없음, 이벤트 IDLE 복귀. 기존 Prompt4의 6명 Queue 최소 간격은 약0.894m로 기존 계약 통과.
- 기존 Prompt0~10.1 **1,058 PASS**, 신규10.2 **31 PASS**, 총 **1,089 PASS**. 기존 단계별 수는 Prompt10.1 기록과 동일하다. 임포트 → 신규10.2 → 기존0~10.1 창 모드 순차 검사 → headless Main 7,200tick(120초 시뮬레이션)을 수행했다. 모두 exit0, 최종 로그에서 SCRIPT ERROR/ERROR:/FAIL: 없음. 입력 검사는 동시에 여러 창을 실행하지 않았다.
- 문서의 기존 Godot 실행 파일 사용. 검사 인수 `--path . --fixed-fps 60 --script res://tests/prompt<단계>_smoke.gd --quit-after 30000 --log-file .godot/p102_verified_<단계>.log`. 최종 로그 `.godot/p102_import_final.log`, `.godot/p102_verified_*.log`, `.godot/p102_main.log`. 최초 재현/신규 로그도 보존했다. 연결 중단 후 실제 파일/실행 상태를 확인하고 신규 검사를 이어서 작성했으며 구현을 중복 적용하지 않았다.
- 최종 Git: 기존20파일 수정, 신규4파일(스크립트2+UID2), 모두 uncommitted. README 입력 변경 없음, AGENTS/Skill 불필요한 변경 없음. 공통 Human 원칙은 이 문서와 helper에 기록했다. `git diff --check` 공백 오류 없음.

### 수동 확인 / Known Issues / 다음 단계

1. F5 → I → U OFF → B: 승객이 입구에서 뭉쳐 정지하지 않고 여러 Shelf/Queue로 진행하는지 확인한다.
2. 정면 교차·Shelf 통로 교차·같은 Shelf 방문을 확인한다. 좁은 곳의 잠깐 겹침은 허용하지만 영구 정체는 안 된다. SHOP 위치와 Queue spacing이 흐트러지지 않는지 확인한다.
3. Player 몸 밀기, Cart 충돌, 상품 투척, Mop 접촉, 소화기 분사를 확인한다. Human끼리만 비충돌이며 이 대상들은 계속 실제 물리 상호작용해야 한다.
4. Rush 중 K/L/T/O/P로 Drunk·가족·Thief·Spill·Fire를 함께 테스트한다. Carry→Drop, Knockdown/Fire 후 원래 목적지 재개, 가족 퇴장을 확인한다.
- Soft Separation은 완벽한 군중 회피가 아니다. 극단적 밀집에서는 겹쳐 통과하며 World/Cart/Player가 막은 길은 여전히 실제 장애물이다.
- **NPC Knockdown Mesh / Collider mismatch**, **Cart Contact Repeated Damage**는 최종 Polish/Combat Physics 재검토 항목으로 유지한다.
- 수동 테스트 정상 후 Prompt11 Combat/Mini Boss 기반 작업으로 이어갈 준비 여부를 판단한다. Monster/Boss/Weapon은 추가하지 않는다.

## Prompt 10.1 — 확장 테스트 매장 / Product Catalog / Auto Stock

2026-10-15 구현 완료. 작업 시작 Git은 clean이었다. 기존 Prompt 기록은 아래에 보존한다. 이번 변경은 commit/amend/reset/push하지 않고 사용자의 수동 검증을 위해 uncommitted로 유지한다. 신규 검사는 **113 PASS / failures 0**이며 전체 회귀 결과는 아래 검증 항목에 기록한다.

### 매장 / 상품 데이터

- Store 바닥은 18×12m에서 **30×12m**로 폭만 확장했다. Backroom/Delivery와 5m rear door, 중앙 진입 동선, Checkout/Entrance/Exit는 유지한다. 기존 중앙 Shelf 3개에 좌측 3개·우측 4개 섹션을 추가했다. 좌우 Shelf는 안쪽을 바라보며 각각 기존 Stock Zone과 다중 Shopping Point를 사용한다. 새 섹션의 Shopping Point span은 0.8m, 기존 것은 0.95m다.
- `ProductDefinition` Resource와 `ProductCatalog`가 id, 표시, scene, 가격/무게/크기/가연성, Shelf 이름/배치/수량/슬롯을 공유한다. `data/products/*.tres`에서 편집한다. 상품 타입마다 새로운 Grab/Throw 시스템을 만들지 않는다.
- **기본 카탈로그 9종 + 기존 Appliance 호환 항목 1종**이다. Appliance의 기존 500달러/8kg과 테스트 씬·회수 호환성을 보존했다. 총 10개 Shelf, 기본 최대 55개. Can 수량은 기존 overstock 계약과 슬롯 크기를 유지하기 위해 권장 10 대신 8이다.

| 상품 | 가격 | kg | 크기 XYZ(m) | 형상 | 가연성 | Shelf 수량 |
| --- | ---: | ---: | --- | --- | --- | ---: |
| Can | 5 | 1 | 0.28×0.32×0.28 | 원기둥 | true | 8 |
| Bread | 10 | 0.5 | 0.50×0.22×0.24 | 긴 Box | true | 8 |
| Milk | 15 | 1.5 | 0.25×0.48×0.25 | Carton Box | false | 8 |
| Glass Drink | 25 | 1.2 | 0.20×0.45×0.20 | 원기둥 | false | 8 |
| Detergent | 30 | 2.5 | 0.36×0.50×0.30 | Box | true | 6 |
| Watermelon | 50 | 4 | 0.56×0.56×0.56 | 구 | false | 5 |
| Frying Pan | 120 | 3 | 0.85×0.12×0.48 | 넓고 얇은 Box | false | 4 |
| Microwave | 300 | 7 | 0.68×0.50×0.45 | Box | true | 3 |
| TV | 800 | 10 | 1.05×0.75×0.25 | 넓은 Box | true | 2 |
| Appliance(호환) | 500 | 8 | 0.70×0.60×0.50 | Box | true | 3 |

### Auto Stock / 실제 물리 진열

- `debug_auto_stock = I`, Mart의 `auto_stock_on_start = false` 기본값. 시작 옵션은 물리 공간 초기화 후 같은 top_up 경로를 호출한다. HUD와 로그에 실제 추가 수를 표시한다.
- 각 Shelf에서 해당 타입의 실제 물리 상품을 세고 Capacity 부족분만 생성한다. 정착 대기 중인 상품도 포함해 같은 프레임에 I를 반복해도 중복 보충하지 않는다. 들고 있거나 판매/삭제 예정인 상품은 제외한다. Stock 숫자를 직접 수정하지 않으며 기존 StockShelf 정착/영역 검사가 정상 등록한다.
- Definition의 행/열 슬롯과 실제 상품 Shape query를 사용한다. 물리 서버에 아직 등록되지 않은 이번 호출의 상품도 임시 AABB 목록으로 확인한다. 슬롯이 막히면 건너뛰며 잘못 놓인 상품·플레이어가 쌓은 물체를 삭제하거나 이동하지 않는다. 따라서 장애물이 있는 Shelf는 I 한 번으로 완전히 차지 않을 수 있다. 공간 확보 후 다시 I를 누른다.
- 예약 상품은 실제 Shelf에 남아 있는 동안 수량에 포함된다. SHOP에서 이미 Picked된 상품은 부족분으로 보충할 수 있으며 기존 Basket을 변경하지 않는다. Physical Overstock을 제한하는 새 규칙은 없다.

### 기존 시스템 연결 / 파일

- 신규 `scripts/systems/product_definition.gd`, `product_catalog.gd`(+UID), `data/products/` 10개 Resource: 공유 데이터와 primitive mesh/shape/slot 생성.
- 신규 `scenes/interactables/products/`의 bread/milk/glass_drink/detergent/frying_pan/microwave/tv 씬. 기존 can/watermelon/appliance도 Definition을 참조한다. 모두 기존 GrabbableBody를 사용한다. 도구는 Definition 없이 기존대로 동작한다.
- `grabbable_body.gd`: Definition 할당 시 기본값 적용, ready에서 mesh/shape 구성. 이후 인스턴스별 값 편집은 유지한다. `thief_manager.gd`: 회수 시 Definition을 먼저 복원하고 저장한 개별 export 값을 나중에 복원해 수정된 가격/무게를 덮어쓰지 않는다.
- `basic_customer.gd`, `purchase_icons.gd`, `customer_manager.gd`: 아이콘/색상/카탈로그 후보를 공통 데이터에서 읽는다. 실제 구매는 기존 실제 Stock/예약 구조를 그대로 사용한다. Tourist도 같은 구매 경로이며 Thief의 실제 Stock 검색, Fire flammable/price, Cart 질량/가격 합산은 기존 구조다.
- `stock_shelf.gd`: Shopping Point span 조절값. `mart_graybox.gd`: 폭 확장, 데이터 기반 추가 Shelf, AutoStock 연결. `auto_stock.gd`(+UID): 보충/슬롯 충돌 검사/HUD. `project.godot`: I 입력.
- `delivery_manager.gd`: 첫 배송은 기존 3종×2개 유지, 이후 9종 카탈로그에서 3종×2개씩 순환한다. `use_catalog_rotation = true`, false이면 기존 Inspector scenes 사용. 팔레트 공간 검사는 실제 상품 크기를 사용한다. `max_active_products = 96`으로 늘려 전체 55개 진열 후에도 배송이 막히지 않게 했다. 배송 위치/카트 운반/수동 진열은 유지한다.
- 신규 `tests/prompt10_1_smoke.gd`(+UID), 수정 `tests/prompt3_smoke.gd`, README와 이 문서. AGENTS/Skill 변경 없음.

### 검증 / 재검사 이력

- 신규 창 모드 검사: 9종 생성/값/전용 Shelf, 55개 실제 진열/정착, 같은 프레임 중복 I, 잘못된 상품 보존/빈 슬롯 보충, 9종 예약, 실제 Bread+TV 양쪽 Shelf 방문 및 E Scan/Pay **$810**, 보충 시 Basket 보존, Grab/Throw/Cart 적재, 주요 측면 통로 1.4m 물리 공간 검사를 포함한다.
- TV 실제 절도 → 좌클릭 Capture → 가격800/무게10/Definition 회수, Fire로 TV 파손 시 **$800 손실 정확히 1회**, 10명 Rush의 여러 상품 구매와 Queue 진행, 4회 배송으로 9종+호환 Appliance 제공, 시작 보충 경로도 검사한다.
- 최초 신규 실행에서 배송의 Glass Drink 2개에 대한 `mass == weight`만 실패했다. 1.2kg 물리 엔진 저장값의 부동소수 정밀도 비교를 `is_equal_approx`로 수정했다. 최종 신규 113 PASS / errors 0. 게임 무게나 배송 기준은 변경하지 않았다.
- 기존 Prompt3의 모든 Shelf가 최초 배송으로 1개씩 채워진다는 fixture는 신규 빈 Shelf 7개 때문에 맞지 않는다. 원래 3종은 1개, 추가 7종은 0개를 검증하도록 갱신했다. 원래 검사 유지 + 신규 빈 Shelf 7건이 추가되어 Prompt3는 32→39개다.
- 실제 매장 렌더 `.godot/p101_store.png`에서 전체 배치와 진열 상태를 확인했다. 자동 검사로 조작감/멀미/혼잡 FPS를 확정하지 않는다.
- 최종 전체 검사 **1,058 PASS / failures 0 / errors 0**: 기존 Prompt0~10은 **945**(기존938 + Prompt3 추가7), 신규10.1은 **113**. 각 실행 exit 0. 0=22, 1=48, 1.1=40, 2=41, 2.1=28, 3=39, 3.1=29, 4=54, 5=33, 5.1=36, 5.2=57, 6=40, 6.1=35, 6.2=48, 7=55, 7.1=57, 7.2=26, 7.3=16, 8=59, 8.1=62, 9=62, 10=58, 10.1=113.
- 문서의 기존 Godot 실행 파일로 headless import 후 신규10.1→기존0~10을 실제 창에서 순차 실행했다. 각 검사 명령은 `--path . --fixed-fps 60 --script res://tests/prompt<단계>_smoke.gd --quit-after 30000`. Main은 headless `--fixed-fps 60 --quit-after 7200`(120초 시뮬레이션)으로 exit 0. 임포트/Main/전체 최종 로그의 SCRIPT ERROR, ERROR:, FAIL: 없음. 로그: `.godot/p101_import_final.log`, `.godot/p101_verified_*.log`, `.godot/p101_main.log`. 최초 실패 로그 `.godot/p101_first.log` 보존.
- 최종 신규 Rush 측정: 승객 10명, 선택 상품 종류 9개(호환 Appliance 포함), Queue 최대 3명. 최종 Git은 기존 파일 15개 수정 + 새 파일 25개(UID 포함), 모두 uncommitted. `git diff --check` 공백 오류 없음(LF/CRLF 안내만 존재).

### 수동 확인 / 알려진 문제 / 다음 작업

1. F5 → U OFF → I: 55개 진열과 물리 폭주 여부 확인. 몇 개를 Grab/Cart/Throw로 꺼내 I로 부족분만 보충. 잘못 쌓인 물체가 삭제되지 않는지 확인.
2. Bread/Can/Watermelon/Pan/Microwave/TV의 무게별 투척 및 크기별 Cart 적재·Cart Bomb 비교. 좌우 통로 직진/회전/U턴 조작감 확인.
3. I → 일반 손님 또는 B: 여러 Shelf 방문, Pickup, Queue, Scan/Pay, 품절/Patience 확인. U 설정은 버스 종료 후에도 보존되어야 한다.
4. I → T: 고가 상품 절도/회수 후 재진열. I → P: Bread/Detergent/TV 등 연소, Fire LOSS 가격 및 소화기 확인. I 없이 배송 상품 직접 운반도 확인.
5. 기존 Fire/Spill/Drunk/LostFamily/Thief/Rush를 함께 실행해 혼잡과 카트 동선을 수동 검증한다.

- 슬롯이 장애물로 막혀 있으면 자동 보충을 건너뛰는 것은 의도된 동작이다. 상품은 최종 아트가 아닌 primitive이며 Pan도 넓고 얇은 Box다.
- **NPC Knockdown Mesh / Collider mismatch**는 Final Polish TODO로 유지한다.
- **Cart Contact Repeated Damage**는 Final Combat/Gameplay/Physics TODO로 유지한다.
- 수동 테스트가 정상이라면 Prompt11 Combat/Mini Boss 기반 작업으로 이어갈 수 있다. 이번 작업에는 Boss/Weapon/새 Event를 구현하지 않았다.

## Prompt 10 — Tourist Bus / Customer Rush

2026-10-15 구현 및 자동 검증 완료. **기존 880 + 신규 58 = 총 938 PASS**. 임포트 및 Main 실행 오류 없음. 작업 시작 Git은 clean으로 Prompt 9가 사용자에 의해 정리된 상태였다. 아래 이전 Prompt의 uncommitted 기록은 당시 이력이다. 이번 작업도 commit/amend/reset/push하지 않았다. 수동 Rush 조작감/혼잡 성능 검증은 사용자 확인 대상이다.

### Event / 승객 / 시각 표현

- 신규 `scripts/systems/tourist_bus.gd`의 `TouristBus`는 Mart의 TouristBus 노드로 연결되는 작은 외부 이벤트다. TouristCustomer 클래스나 별도 쇼핑/계산 AI는 없다. 개발용 `debug_tourist_bus = B`, IDLE에서만 시작한다.
- IDLE → ARRIVING(2초) → UNLOADING → RUSH_ACTIVE → DEPARTING(2초) → IDLE. 노란 Box 차체, 푸른 창문, 바퀴 표시, 이동하는 문, BUS 표식을 사용한다. 외부 (16,0,15)에서 주차 위치 (2,0,15)로 단순 이동하고 같은 방향으로 떠난다. 차량 물리/운전/피해는 없다. 차체 StaticBody collision은 유지한다.
- 기존 외부 입구 바닥을 덮지 않고 좌/우/뒤의 3개 바닥 조각으로 버스 앞 공간을 확장했다. 최초 렌더에서 같은 높이의 바닥 중첩으로 보인 줄무늬를 제거하기 위한 분할이다. 내부 마트·배송 동선은 바꾸지 않았다.
- 승객은 실제 PassengerDoor 앞 (-1.4,0.01,13.0)에서 생성한다. (-4.15,0.01,13) → (-4.15,0.01,10.8)로 입구의 한쪽을 사용한 뒤 기존 매장 waypoint에 합류한다. 기본 0.4초 간격이며 같은 physics tick에 여러 명을 생성하지 않는다. 문 앞 고객과 최소 0.85m 거리 및 radius 0.4 물리 공간을 확인해 겹치면 다음 기회에 retry한다. 순간이동/전역 collision ghost/crowd avoidance는 추가하지 않았다.
- 기본 10명, 2~4개 구매. 가능한 실제 비예약 재고에서 기존 Purchase List를 생성한다. 남은 재고가 1개라면 1개를 요청하며, 재고가 없으면 기존 OOS 요청/퇴장 흐름이다. 기존 Reservation → Shopping Point → SHOP → 실제 상품 제거/Basket → Queue → Scan/Pay → Exit를 모두 재사용한다.
- 승객은 `tourist` 메타데이터만 가진 원래 BasicCustomer다. Patience는 기존 CustomerManager 값 25초 그대로이며 tourist 전용 값이 없다. Shopping Point 점유/retry, FireReaction, Knockdown, 외력은 기존 코드다.

### Customer 제한 / U 설정 보존 / 완료 조건

- `CustomerManager.max_active_customers = 6` 유지. 정상/Accident/Dangerous 등 비관광 Customer 수를 이 제한으로 센다. 관광 승객은 별도 생성 요청으로 이 제한을 넘을 수 있으며 기존 관광 손님이 남아 있어도 정상 손님 제한을 영구 변경하지 않는다.
- 신규 `absolute_customer_cap = 18`은 CustomerManager 관리 목록 전체(정상/Accident/Dangerous/관광)에 적용한다. 버스 목표 인원은 1~absolute cap으로 clamp한다. Thief/Drunk/LostFamily는 원래 독립 매니저/자체 상한을 유지하며 이 18명에는 포함하지 않는다. 전체 월드 NPC를 하나의 전역 Manager로 통합하지 않았다.
- 사용자 `spawning_enabled`와 신규 `event_spawn_paused`를 분리했다. 버스 중에는 자동 생성 타이머만 멈춘다. 표시에는 `(BUS PAUSE)`가 붙는다. 버스 종료 시 pause만 해제하므로 ON은 재개, OFF는 유지된다. 버스 도중 사용자가 U를 변경해도 가장 최근 선택을 존중한다. Event Manager가 제거될 때도 pause를 해제한다.
- 모든 승객을 생성하면 RUSH_ACTIVE. 기본 80%가 resolved(정상 결제/OOS/미결제 처리) 또는 이미 제거되면 출발한다. 한 명이 끼어도 기다리지 않는다. `max_rush_duration = 100초`는 ARRIVING부터 UNLOADING까지 포함하는 안전 타이머이므로 문/상한 때문에 마지막 승객을 생성하지 못해도 이벤트가 종료된다.
- 이미 생성된 손님은 버스 출발 시 강제로 삭제하지 않는다. 기존 구매/Queue/Patience/퇴장을 계속한다. 중단된 하차의 미생성 인원은 강제로 추가 생성하지 않는다. 다음 B 이벤트는 IDLE에서 가능하며 기존 남은 승객까지 absolute cap에 포함된다.

### Stats / 기존 업무 압박

- `tourist_buses_arrived`: 실제 정차 완료 시 +1.
- `tourist_customers_served`: CustomerManager의 성공적인 정상 결제 후 `customer_paid` signal을 받아 관광 승객만 +1. 기존 resolved guard와 결제 instance_id 중복 방지로 이중 집계하지 않는다. OOS/Patience Escape는 served가 아니다. 버스 출발/다음 이벤트 후 늦은 정상 결제도 누적 통계에 포함할 수 있도록 현재 passenger 배열에 한정하지 않는다.
- Sales/Unpaid Loss는 원래 회계 그대로이며 별도 Tourist Revenue/Stock Penalty는 없다. 상품 감소와 Queue 압박은 실제 쇼핑의 결과다. HUD의 ACTIVE는 아직 해결되지 않은 이번 버스 승객 수이며 월드에 남아 있는 전체 NPC 수가 아니다.
- 기존 K/L/O/P/T/F 및 계산/카트/배송 입력은 막지 않는다. 수동 특수 손님은 원래 자체 제한·입구 점유 규칙을 계속 따른다. 관광 인원만으로 비관광 손님 6명 제한을 채우지 않으므로 Rush 중 O/P도 생성 가능하다(absolute cap 미만일 때).

### 실제 Inspector 기본값

| 위치 | 변수 | 기본값 |
| --- | --- | --- |
| TouristBus | tourist_count | 10 |
| TouristBus | passenger_spawn_interval | 0.4초 (최저 0.1초) |
| TouristBus | min_purchase_units / max_purchase_units | 2 / 4 |
| TouristBus | arrival_time / departure_time | 2 / 2초 |
| TouristBus | max_rush_duration | 100초 |
| TouristBus | completion_ratio | 0.8 |
| CustomerManager | max_active_customers / absolute_customer_cap | 6 / 18 |

### 파일 / 검사 이력

- 신규 `scripts/systems/tourist_bus.gd`(+UID): 이벤트, 버스 Graybox, 순차 생성, 타임아웃, HUD, 도착/served 통계.
- 수정 `scripts/systems/customer_manager.gd`: 선택적인 event_options로 기존 생성 경로 재사용, 비관광/전체 cap, 사용자 설정과 event pause 분리, 정상 결제 signal.
- 수정 `scripts/systems/mart_graybox.gd`: TouristBus 연결. `project.godot`: B 입력.
- 신규 `tests/prompt10_smoke.gd`(+UID): 실제 창에서 입구→Shelf→Pickup→Queue→결제, 10명 순차 생성/상한/설정/품절/타임아웃/다른 이벤트 검증.
- README와 이 문서에 조작/구조/한계 기록. AGENTS/Skill/기존 Prompt 테스트는 변경하지 않았다.
- 첫 신규 통합 검사 failures 0: 실제 재고 14개, 승객 10명, 활성 Customer 최대 9명, Queue 최대 5명 측정. 한 명은 실제 E Scan/Pay로 결제하고 나머지는 기존 Patience/OOS를 진행했다. 서로 같은 상품을 예약하지 않는 것도 매 tick 검사했다.
- 검사를 보강하면서 `get_node()` 반환값의 `accident :=` 타입 추론으로 신규 테스트가 parse 실패했다. 명시 `AccidentCustomer` 타입으로 수정했다. 그 다음 실행에서 생성 간격 검사 1개가 실패했다. 계산 입력 await 동안 물리 시간이 흐르는데 테스트 루프 반복 횟수만 세던 측정 오류였다. 물리 프레임 번호로 바꿔도 관측 자체가 계산 입력 await 뒤에 이루어져 같은 항목이 다시 실패했다. 최종적으로 `CustomerManager.child_entered_tree` signal에서 실제 생성 순간을 기록하도록 수정했다. 게임 spawn_interval은 그대로이며 검사 하한은 정확한 24 physics ticks(0.4초)로 강화했다. 최초 로그는 보존한다.
- 실제 버스 렌더 `.godot/p10_bus.png`를 확인하고 바닥 Z-fighting 제거 및 HUD를 계산 패널 아래 y=260으로 이동했다. 수정 후 렌더도 확인했다. 외부 바닥 수정 후 가족 퇴장(6.1)/도둑(9)/버스(10)/Main 추가 검증도 통과했다.
- 기존 전체 회귀: 0=22, 1=48, 1.1=40, 2=41, 2.1=28, 3=32, 3.1=29, 4=54, 5=33, 5.1=36, 5.2=57, 6=40, 6.1=35, 6.2=48, 7=55, 7.1=57, 7.2=26, 7.3=16, 8=59, 8.1=62, 9=62 → **880 PASS**, 각 exit 0 / errors 0.
- 최종 Prompt 10 **58 PASS / failures 0 / exit 0**. 생성 순간 physics frames = [303,328,353,378,403,428,453,603,753,903]: 최소 25 ticks, 입구 점유 시 더 오래 기다렸다. 총 10명, peak active 9, peak queue 5. 정상 결제 1명, 재고 감소/Patience 손실/중복 Reservation 없음, U 상태 보존, OOS 입구 퇴장, 절대 cap/하차 타임아웃, Fire/Spill 상태 복구, K/L/O/P/T 수동 생성 모두 통과.
- 외부 바닥 수정 후 6.1=35 PASS, 9=62 PASS 추가 확인. 기존 880개에 중복 재실행 수는 더하지 않는다. 합계 **938 PASS**.
- 기존 Godot 경로 `D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe` 사용. 임포트는 `--headless --path . --editor --import --quit`; 창 테스트는 `--path . --fixed-fps 60 --script res://tests/prompt<번호>_smoke.gd --quit-after 24000`로 순차 실행(파일명의 소수점은 `_`). Main은 `--headless --path . --fixed-fps 60 --quit-after 7200`로 120초 시뮬레이션, exit 0.
- 최종 로그: `.godot/p10_import_final.log`, `.godot/p10_regression_*.log`, `.godot/p10_verified_6_1.log`, `.godot/p10_verified_9.log`, `.godot/p10_spawn_verified.log`, `.godot/p10_main_final.log`. 최종 선택 로그에 SCRIPT ERROR/ERROR:/FAIL: 없음. `p10_final.log`(테스트 parse), `p10_recheck.log` 및 `p10_verified_10.log`(간격 측정 실패)은 진단 이력으로 보존한다. `git diff --check` 통과.

### 수동 테스트 / 알려진 한계 / 다음 단계

1. F5 → U OFF → 충분한 실제 상품 진열 → B. 외부 버스 도착/문 이동/승객 순차 입장, 다른 자동 손님 없음 확인.
2. 진열 재고 소비/여러 Shopping Point 분산/Queue 증가 확인. Scan/Pay로 정상 결제할 때만 SERVED와 Sales 증가 확인. 재고가 적으면 품절 손님이 많으므로 입고 상품을 계속 보충한다.
3. U ON/OFF 각각 버스 종료 후 설정 유지 확인. 이벤트 중 U 변경도 확인한다. 기존 손님이 많은 상태에서도 cap과 타임아웃이 작동해야 한다.
4. Rush 중 K/L/O/P/T로 특수 손님 생성. Spill Recover/FireReaction 후 구매 상태 유지, Thief 추격/포획, 가족 퇴장과 계산/카트/배송 병행 확인.
5. 버스 출발 후 남은 손님 계속 진행/늦은 결제 집계/다음 B 호출 확인.

생성 간격은 최소 재시도 간격이며 입구 공간이 막히면 실제 하차가 더 느릴 수 있다. 100초 만료 시 전원을 생성하지 못한 채 출발할 수 있다. 기본 Shelf 권장 재고 합계는 16개라 10명이 2~4개씩 모두 구매하려면 재진열이 필요하다. 기존 waypoint NPC는 실제 물리 장애물을 우회하는 완전한 Crowd AI가 아니며, 극단적 혼잡의 수동 feel/성능 검증은 남는다. 일반 손님 수만 늘렸으며 게임을 잠그는 모드나 새 관광 전용 규칙은 없다.

**Final Polish TODO 유지:** NPC Knockdown Mesh ↔ upright Collider mismatch / Cart Contact Repeated Damage. 이번 단계에서 수정하지 않았다.

수동 검증 정상 후 Prompt 11 Combat / Boss progression으로 확장할 기반이 된다. 무기/Boss/Random Event Director/Round Director/Result Screen/Multiplayer는 구현하지 않았다.

## Prompt 9 — Thief Customer / Chase / Stolen Goods

2026-10-14 구현 및 자동 검증 완료. 기존 818 + 신규 62 = 총 **880개 통과**, 임포트/Main 오류 없음. 실제 추격 조작감은 사용자 수동 확인 대상이다. 이번 시작 시 Git 변경은 `project.godot`의 기존 U 입력 직렬화 변경만 존재했으며 보존했다. 이전 Prompt의 uncommitted 파일 목록은 당시 이력이다. 이번 작업에서 commit/amend/reset/push하지 않았다.

### 상태와 기존 코드 재사용

- `ThiefCustomer extends BasicCustomer`. 전용 상태는 APPROACH → STEAL → ESCAPING → CAPTURED, 또는 상품이 없어진 경우 LEAVING이다. BasicCustomer의 waypoint 이동, CharacterBody 충돌, 외력, FireReaction, Knockdown을 재사용한다. 내부 Basic state EXIT는 waypoint 이동 분기를 쓰기 위한 값이며, 절도 전에도 실제 퇴장을 뜻하지 않는다. `finish_exit()`가 APPROACH 도착이면 STEAL로 전환한다.
- `ThiefManager`는 Mart의 `Thieves` 노드다. T 개발용 생성, 최대 2명, 입구 점유 검사를 수행한다. 일반 CustomerManager의 customers/Queue에는 등록하지 않는다. U OFF에서도 T는 작동하고 기존 다른 특수 손님 및 업무를 정지시키지 않는다.
- 실제 Shelf Stock 후보에서 `1 + 0.25 * log(1 + price)` 가중치로 하나를 선택한다. 고가에 약한 편향만 있다. 실제 상품 가까운 기존 Shopping Point를 예약해 기존 통로로 접근한다. 재고/Shopping Point가 없거나 목표가 이동·삭제·파손되면 빈손 퇴장한다. 가짜 상품/손실을 생성하지 않는다.
- 도착 후 0.6초 동안 Shelf를 바라보고 다시 `has_stock`으로 확인한 다음 절도한다. FireReaction/Knockdown 동안 기존 이동 및 절도 타이머 진행을 쉬고 동일한 상태로 복귀한다. 넘어져 있어도 절도 후에는 포획 가능하다.
- Escape는 3.8m/s(기본 Customer 2.2, Player 5)다. 기존 매장 통로 waypoint를 따르되 정상 손님의 내부 Exit 지점에서 끝내지 않고 Entrance보다 바깥쪽 1.75m 지점을 추가한다. 현재 실제 종료 좌표는 약 (-3, 0.01, 13.6), 판정 거리 0.5m다. 실제 출구 밖에 도달해야 손실을 기록한다.

### 실제 상품 / 논리 Loot / Reservation

- 훔치는 순간 원래 상품을 hide + queue_free하고 Shelf.refresh_stock(0)로 수량을 즉시 반영한다. `stolen_item`은 product_type, price, weight, source_id, 원래 scene 경로, 실제 인스턴스의 exported script 설정 및 주요 native physics 설정을 저장한다.
- 상품 3D 오브젝트를 손에 붙이지 않는다. 머리 위에는 원래 Mesh/material을 이용한 작은 상품 표시만 생성한다. 도주 중 `!!`, 포획 후 ✓와 상품 표시 숨김을 사용한다. 실제 렌더 `.godot/p9_theft.png`에서 Appliance 표시와 빈 Shelf를 확인했다.
- 이미 일반 손님이 예약한 상품도 훔칠 수 있다. 기존 예약은 원래 Node를 가리키므로 삭제 후 정상 Out of Stock으로 빠진다. 일반 Basket에 이미 들어간 상품은 Shelf에 없으므로 절도 후보가 아니다. Checkout/Sales/Unpaid Loss 구조는 변경하지 않는다.
- queued node는 기존 판매/Fire 검증에서 제외된다. 회수 상품은 새 instance_id이며 원래 stolen/broken 메타데이터를 복제하지 않는다. 같은 원본을 목표로 삼은 도둑 2명 중 먼저 훔친 한 명만 Loot를 소유하고 나머지는 빈손 퇴장한다.

### Capture / 실제 상품 회수 / 회계

- 기존 PlayerInteraction 좌클릭에서 실제 Ray에 잡힌 `ThiefCustomer`를 구분한다. 거리 1.8m 이내, ESCAPING, Loot 보유, Player가 Knockdown 아님일 때 Capture. 들고 있던 물건이 있으면 기존대로 먼저 Drop한다. Carry 대상이나 Charge Throw 대상으로 만들지 않는다.
- Ray mask는 기존 상품/카트용 body layer 1|2를 사용한다. Fire/Spill 등의 센서가 도둑을 가리지 않으며 실제 벽은 계속 Grab을 막는다.
- Capture 시 원래 PackedScene을 instantiate하고 저장한 설정을 복원한다. 주변 네 방향과 중심에서 carry_radius 기반 sphere 검사로 바닥 위 회수 공간을 찾는다. Player/벽/다른 물체를 제외하지 않는다. 성공하면 Mart/Products에 실제 물리 상품을 추가하고 thieves_caught +1, Loot clear, 0.7초 ✓ 후 도둑 Despawn.
- 주변 다섯 위치가 모두 막히면 Capture를 완료하지 않고 Loot도 보존한다. 공간을 확보하고 다시 좌클릭할 수 있다. 상품을 geometry 안에 강제 생성하거나 회수 없이 성공 처리하지 않는다.
- 밖으로 도주하면 resolved guard를 설정하고 stolen_goods_value에 Loot.price를 한 번만 더하고 Loot clear 후 Despawn. 포획에는 stolen_goods 손실이 없다. Sales/Unpaid/Fire/Broken 통계를 따로 증가시키지 않는다. HUD `[T] CAUGHT n / STOLEN $n`으로 확인한다.
- 회수 시 현재 상품 scene의 형상과 저장한 exported/physics 설정을 복원한다. 임의 런타임 자식 Mesh/Collider 편집까지 통째로 직렬화하는 Inventory는 만들지 않았다. 현재 3종 및 price/weight/carry_radius/flammable 인스턴스 변경을 검증했다.

### Toy Interaction / 다른 가족과의 충돌

- Spill Knockdown / FireReaction은 상속된 공통 처리다. 회복 후 원래 Escape waypoint와 Loot를 유지한다. Extinguisher도 기존 apply_external_impulse로 밀며 전용 Thief stun이 없다.
- 기존 Cart contact push를 그대로 재사용한다. Mop/상품 RigidBody 접촉은 상대속도·질량에 따른 제한된 외력을 같은 NPC motor에 전달한다. Player의 기존 접촉 push 경로에도 CharacterBody의 apply_external_impulse를 연결했다. 몸/카트/소화기 접촉은 자동 Capture하지 않는다.
- BasicCustomer에 `basic_customers` 그룹을 등록하고 LostFamilyManager의 출발 가족 exception 갱신이 이 그룹을 사용하도록 최소 수정했다. 정상 손님 명단 밖의 기존 도둑도 Departing Family와 양방향 예외를 받는다. 가족 외 NPC를 전역 ghost로 바꾸지 않는다.
- 실제 카트/상품/벽 길막은 유지한다. 새로운 Crowd AI/우회 경로 탐색은 만들지 않았으므로 물체로 통로를 막으면 도둑이 멈출 수 있다.

### Inspector 기본값 / 파일

| 위치 | 변수 / 값 |
| --- | --- |
| ThiefCustomer | escape_speed 3.8m/s / steal_time 0.6초 |
| ThiefCustomer | capture_distance 1.8m / capture_feedback_time 0.7초 |
| ThiefManager | enable_thief_test_spawn true / max_active_thieves 2 |
| ThiefManager | high_value_bias 0.25 |

- 신규: `scripts/systems/thief_customer.gd`, `thief_manager.gd`, 각각의 Godot UID, `scenes/interactables/thief_customer.tscn`, `tests/prompt9_smoke.gd` 및 UID.
- 수정: `project.godot`(T), `player_interaction.gd`(Capture Ray/input), `player_controller.gd`(NPC body push), `basic_customer.gd`(그룹), `lost_family_manager.gd`(departing exception 대상), `mart_graybox.gd`(Thieves), README, 이 문서.
- AGENTS/Skill 및 기존 Prompt 테스트는 변경하지 않았다.

### 검증 이력 / 최종 결과

- 신규 테스트의 첫 실행에서 PhysicsBody로 넓힌 push 분기의 closing_speed 타입 추론 오류를 발견해 명시 float로 수정했다. 그로 인한 Player script 로드 실패 후 검사는 중단하고 재실행했다.
- 빈손 퇴장의 불필요한 실내 역주행을 입구 근처 직접 outside route로 수정했다. 신규 테스트의 잘못된 Cart node 경로도 실제 `Cart`로 수정했다. 이후 핵심 절도/회수/도주/Spill/Fire 검사는 통과했다.
- 물리 접촉 검사 확장 중 분사 후 Escape 재개 한 항목이 실패했다. 실제 slide collider를 조사하니 테스트 동선의 원래 Cart가 막고 있었다. 해당 접촉 fixture에서만 Cart를 옮기고, 별도 Cart 충돌 검사는 유지했다. AI 속도 기준을 약화하거나 실제 길막을 제거하지 않았다.
- 첫 전체 회귀에서 Prompt 6.1의 `unresolved other family collision remains enabled` 1개가 실패했다. 새로운 basic_customers 그룹에 LostParent도 포함되어 미해결 부모를 예외 대상으로 확장한 실제 회귀였다. 그룹 순회에서 LostParent를 제외하여 기존 규칙을 복원했다. 재회한 가족끼리는 원래 departing 목록에서 별도 처리하며, 도둑과의 예외는 유지한다. 기존 테스트는 수정하지 않고 Prompt 6.1(35 PASS), 9(62 PASS)를 재검증해 모두 통과했다. 최초 실패 로그도 보존했다.
- 최종 Prompt 9: **62 PASS / failures 0**. 실제 입구→Shelf→절도, 실제 밖으로 도주, U OFF T 생성, 예약 OOS, 중복 절도/손실 방지, 좌클릭 Capture, 벽으로 Capture 차단, 넘어져 있을 때 Capture, 인스턴스 설정 복원, 실제 Grab/Throw/재진열/Cart 적재, 소화기/Mop/Cart/Player push 및 Escape 복귀, 출발 가족 예외를 검사했다.
- 최종 회귀: 0=22, 1=48, 1.1=40, 2=41, 2.1=28, 3=32, 3.1=29, 4=54, 5=33, 5.1=36, 5.2=57, 6=40, 6.1=35, 6.2=48, 7=55, 7.1=57, 7.2=26, 7.3=16, 8=59, 8.1=62, 9=62. 합계 **880 PASS**, 최종 각 실행 failures 0 / exit 0. 수정된 가족 예외 범위를 사용하는 Knockdown/Fire 회귀도 통과했다.
- Godot 4.7.2 경로는 기존 `D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`. 임포트는 `--headless --path . --editor --import --quit`, 창 테스트는 `--path . --fixed-fps 60 --script res://tests/prompt<번호>_smoke.gd --quit-after 24000`으로 순차 실행했다(소수점은 파일명에서 `_`). Main은 `--headless --path . --fixed-fps 60 --quit-after 7200`, 시뮬레이션 120초, 정상 종료 및 배송 도착/출발 확인.
- 로그: `.godot/p9_import_final.log`, `.godot/p9_final.log`, `.godot/p9_regression_*.log`, `.godot/p9_recheck_6_1.log`, `.godot/p9_recheck_9.log`, `.godot/p9_main.log`. 최종 선택 로그에서 SCRIPT ERROR/ERROR:/FAIL: 없음. 최초 회귀 6.1 로그는 실패 이력으로 남겨둔다. `git diff --check` 통과(Windows 줄바꿈 안내만 존재).

### 수동 확인 / 알려진 문제 / 다음 작업

1. F5 → U OFF → 이미 있던 손님 처리 → 상품 진열 → T. 진열대 앞 절도 후 해당 상품 하나가 사라지고 상품 표시/!!와 함께 도주하는지 확인한다.
2. 추격해 빈손으로 도둑을 바라보고 1.8m 이내 좌클릭. ✓/CAUGHT 증가/바닥 상품 회수, STOLEN 불변을 확인한다. 회수 상품 Grab/Throw/Cart/재진열도 확인한다.
3. 다시 T로 생성하고 놓친다. 실제 문 밖에서만 사라지고 원래 가격만큼 STOLEN이 한 번 증가해야 한다.
4. 예약 상품 절도 시 정상 Customer는 OOS, 재고 없는 도둑은 빈손 퇴장인지 확인한다.
5. Spill을 도주 경로에 두어 넘어짐→회복→도주, 넘어진 중 좌클릭 Capture를 확인한다. Fire 및 F 분사/Mop/Cart로 물리적으로 밀어도 자동 Capture되지 않는지 확인한다.
6. Customer/Checkout/Drunk/LostFamily/Fire/Spill/Delivery와 함께 실행하고 사건이 전체 게임을 잠그지 않는지 확인한다.

자동 검사는 완료 여부와 기능을 확인하지만 추격 반응 시간/혼잡 구간/상품 표시 가독성의 최종 feel 승인은 수동 테스트로 남는다. 입구가 점유되면 Debug Spawn은 생략하므로 길을 비우고 다시 T를 누른다. 회수 공간이 완전히 없으면 Capture 재시도가 필요하다. 기존 waypoint AI는 실제 물리 장애물을 자동 우회하지 않는다.

**Final Polish TODO (의도적으로 미수정):** NPC Knockdown Mesh ↔ upright Collider mismatch, Cart Contact Repeated Damage. 전체 기능/전투 구현 뒤 재검토한다.

수동 검증 정상 시 다음 요청 Prompt 10 Tourist Bus / Customer Rush로 진행할 기반이 있다. 이번 단계에서 Tourist Bus, 무기, Health, Round Director, Multiplayer는 구현하지 않았다.

## Prompt 8.1 — Fire Character Reaction / Fire LOSS Test Controls

2026-10-03 시작, 2026-10-04 구현·전체 자동 검증 완료. 총 818개 통과, 상세 결과는 아래 최종 검증 기록을 확인한다. 손맛 수동 검증은 별도다. 시작 시 Prompt 8의 tracked 수정 7개 / untracked 15개가 그대로 존재했으며 보존하고 이어서 작업했다. 아래 Prompt 8 기록을 덮어쓰거나 commit/reset하지 않았다.

### 실제 원인과 공통 반응 구조

- 기존 FireManager는 상품 피해 tick(0.5초)에서 NPC에 작은 단발 impulse만 주었다. NPC는 원래 목적지 AI를 계속 실행하여 외력을 곧 상쇄했고 Player는 대상 목록에 없었다. 상태/업무가 잠시 중단되는 표현도 없었다.
- 신규 `FireReaction`은 작은 공통 RefCounted helper다. Player / BasicCustomer / CarryableCharacter가 각각 한 개 보유한다. Accident/Dangerous/LostParent는 Basic 경로, Drunk/LostChild는 Carryable 경로를 상속한다. 새 이벤트나 Health 시스템을 만들지 않았다.
- FireManager는 매 physics tick 실제 Area overlap + 기존 몸통 LOS로 접촉을 검사한다. 열 누적 tick과 분리하여 진입 반응 지연을 줄였다. 캐릭터별 active/cooldown이 모든 Fire에 공통 적용되어 겹친 Fire가 반응을 중첩하지 않는다. `_panic`은 기존 테스트에서 사용하는 최근 반응 진단 기록으로 유지한다.
- Player: 0.3초 화면 좌우 각 3% 폭 주황 표시 + 수평 바깥 방향 가속 30m/s². 기존 이동/마우스/점프/Interaction/도구는 잠그지 않는다. 카메라 회전·Backward Fall offset은 변경하지 않는다. 바깥 방향 밀림은 기존 가속/충돌과 함께 적용되며 순간이동하지 않는다.
- NPC: 0.65초 큰 `:O !!` Bubble과 최대 목표 속도 2.6m/s의 바깥 방향 이동, 수평 보정 가속 18m/s². CharacterBody는 move_and_slide, Carryable은 integrate_forces의 기존 물리 충돌을 유지한다. World collision이나 가족 NPC collision exception을 변경하지 않았다.
- NPC 기존 state enum, Shopping Points, 예약/Basket, Queue 순서, waypoints는 보존한다. 반응 동안 업무 타이머·AI 진행을 잠시 쉬고 종료 후 다음 정상 tick에서 그대로 재개한다. 계산 대상이 반응 중이면 Scan/Pay도 잠시 거절하지만 Player 전체 입력은 잠그지 않는다. Drunk의 방향 선택, Child Follow도 반응 후 계속된다.
- 캐릭터당 시작 간격 1.1초, 동시 한 반응. Carry/Knockdown 중 새 반응을 막고, 반응 도중 Carry/Knockdown이 시작되면 반응 표시를 정리한다. 따라서 Fire→Spill Knockdown은 가능하지만 Fire 자체는 Knockdown을 발생시키지 않는다. 소화기 외력과 중첩되어도 반응 시간을 반복 초기화하지 않는다.

### Customer Auto Spawn / 개발용 키

- `toggle_customer_spawn = U`. 기존 CustomerManager.spawning_enabled를 토글한다. `[U] CUSTOMER SPAWN: ON/OFF` 표시와 로그가 즉시 갱신된다. Inspector/코드에서 flag를 변경해도 표시가 맞도록 setter를 둔다.
- 기본 ON과 6~10초 간격, 인원 제한은 그대로. OFF 동안 자동 생성 타이머만 정지하며 ON 시 남은 타이머부터 재개한다. 기존 손님을 삭제하거나 쇼핑을 멈추지 않는다.
- 수동 K/L/O/P 생성은 별도 경로라 OFF에서도 동작한다. 각 기존 인원 상한/입구 점유 검사는 유지한다. P 손님도 정상 구매하므로 테스트할 상품을 여러 개 준비해야 한다.

### 상품 Burn / Loss 표시

- 연소 노출 중인 실제 상품 위에 `🔥 진행률%` Label3D를 표시한다. 초기 렌더에서 불꽃에 가려져, 상품의 회전과 무관하게 world up 2.2m 위치로 표시를 올렸다. 복잡한 Shader/재질 공유 변경 없이 기존 상품 물리를 유지한다.
- 현재 노출이 없어지면 다음 피해 tick(최대 약 0.5초)에 표시를 숨긴다. Prompt 8처럼 누적 heat는 유지되고 추가 누적만 중단한다. 진압했다고 이미 누적된 열을 초기화하지 않는다.
- threshold 도달 시 기존 실제 상품 제거/단일 price 손실은 즉시 수행한다. 위치에 `🔥 -$가격` 표시가 0.65초 위로 올라가며 사라진다. 판매/연소 구분을 위해 통계를 명시적 **FIRE LOSS: $...**로 바꿨다. 파괴 시 지연 판매 가능 상태를 남기지 않는다.

### 주요 값 / 파일

| 위치 | 변수 / 기본값 |
| --- | --- |
| FireManager Inspector | fire_reaction_cooldown 1.1초 |
| FireManager Inspector | player_reaction_duration 0.3초 / npc_reaction_duration 0.65초 |
| FireManager Inspector | retreat_speed 2.6m/s |
| FireReaction motion | 수평 보정 가속 18m/s² |
| Player reaction | 바깥쪽 가속 30m/s², 좌우 표시 각 화면 폭 3% |
| Burn 표시 | world up 2.2m / 소실 표시 0.65초 |

- 신규 `scripts/interaction/fire_reaction.gd`와 UID: active/cooldown/방향/공통 피드백/후퇴 이동.
- 신규 `tests/prompt8_1_smoke.gd`와 UID: 실제 입력 토글·Player 반응·3종 쇼핑 NPC·Queue/결제 재개·취객·가족 퇴장·Burn/Loss 검사.
- 수정 `scripts/player/player_controller.gd`, `scripts/systems/basic_customer.gd`, `scripts/interaction/carryable_character.gd`: 공통 반응 수명 및 이동 연결.
- 수정 `scripts/systems/accident_customer.gd`, `dangerous_customer.gd`, `drunk_customer.gd`, `lost_child.gd`: 반응 중 파생 AI/timer 진행 중단. LostParent는 상속 처리하고 별도 스크립트를 고치지 않았다.
- 수정 `scripts/systems/fire_manager.gd`: 즉시 Character 접촉, 설정, Burn/소실 표시, 명시적 손실 통계.
- 수정 `scripts/systems/customer_manager.gd`, `checkout.gd`, `project.godot`: U 토글/표시, Panic 중 Scan/Pay 방지, InputMap.
- README/PROJECT_NOTES 갱신. 기존 Prompt 0~8 테스트 파일, Hold/Cart/Spill/Knockdown/Extinguisher 코드는 이번 단계에서 변경하지 않았다. Agent/Skill도 변경하지 않았다.

### 검사 이력

- `.godot/p81_new.log`: BurnFeedback 노드를 Dictionary key에서 조회할 때 타입 추론 오류. Label3D 명시로 수정했다. 이 때문에 의존 스크립트가 실패한 최초 검사 실행은 중단했고 성공으로 세지 않는다.
- `.godot/p81_new2.log`: 신규 fixture에서 무재고 고객의 정상 실망 대기를 이동 실패로 판단했고, 실제 반응 방향이 +Z인데 X 이동만 가정한 3개 검사가 실패했다. 재고 준비 및 실제 바깥 방향 dot/displacement 확인으로 수정했다. 생산 코드 기준을 완화하지 않았다. `.godot/p81_new3.log` 당시 전체 신규 검사 통과.
- 추가 Queue 검사/상태 표시 중 setter 선언의 콜론 누락으로 `.godot/p81_final.log`와 `p81_regression_8.log` 파싱 실패. 구문 수정 후 `.godot/p81_verified.log`에서 추가 Queue fixture가 SHOP 전제 없이 Pickup을 직접 호출한 오류를 발견했다. 실제 쇼핑→Checkout을 기다리는 흐름으로 수정했다. `.godot/p81_verified_8.log` 기존 Prompt 8은 59개 통과.
- `.godot/p81_complete.log`: 최종 신규 **62개 통과**, 종료 0/실행 오류 없음. Player 반응·조작 유지·겹친 불·cooldown·Knockdown 우선, 일반/사고/화재 손님 업무 복귀, 실제 Basket/계산 복귀, Drunk/Child/Parent, 재회 가족의 최종 Despawn, U 토글/기존 고객/수동 생성, Burn/진압 중단/단일 손실을 확인했다.
- `.godot/p81_player_feedback.png`, `p81_burn_feedback.png` 렌더를 확인했다. 화면 가장자리와 불꽃 위 연소 아이콘이 보이는 것을 확인했지만 사용자 수동 손맛 검증을 대신하지 않는다.
- 최종 테스트 검토에서 K/L 검사를 관리 노드의 자식 수 대신 실제 DrunkCustomer 인스턴스와 가족 pair 수로 강화했다. `.godot/p81_complete_verified.log`에서 신규 62개 모두 다시 통과했다. 초기 파싱 실패 당시의 `p81_regression_8.log` 경로는 전체 회귀 실행에서 최종 정상 로그로 갱신되었으며, 해당 파싱 오류 내용은 `p81_final.log`에 남아 있다.

### Prompt 8.1 최종 자동 검증

**기존 756개 + 신규 62개 = 총 818개 통과.** 기존 테스트 파일/검사 기준 변경 없음. 전체 회귀 순차 실행에서는 실패 없이 통과했다. 위 신규 개발 중 수정·재검사 이력과 구분한다.

| Prompt | 통과 |
| --- | ---: |
| 0 / 1 / 1.1 | 22 / 48 / 40 |
| 2 / 2.1 | 41 / 28 |
| 3 / 3.1 | 32 / 29 |
| 4 | 54 |
| 5 / 5.1 / 5.2 | 33 / 36 / 57 |
| 6 / 6.1 / 6.2 | 40 / 35 / 48 |
| 7 / 7.1 / 7.2 / 7.3 | 55 / 57 / 26 / 16 |
| 8 / 8.1 | 59 / 62 |

- `.godot/p81_regression_<번호>.log`, `.godot/p81_complete_verified.log`: 모두 종료 0, FAIL/SCRIPT ERROR/ERROR 0건. 창 모드 fixed-fps 60으로 순차 실행했다.
- `.godot/p81_import_verified.log`: 최종 임포트 종료 0/오류 없음. `.godot/p81_main.log`: Main headless 7200 tick / 120초 시뮬레이션 종료 0/오류 없음, 배송 도착·출발 확인.
- 신규 검사 재실행: `& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --path . --fixed-fps 60 --script res://tests/prompt8_1_smoke.gd --quit-after 10000`.
- `git diff --check` 통과. 이전 Prompt 8 변경을 포함한 working tree: tracked 수정 13개 / 신규 19개(UID 포함). 이번 단계 신규 파일은 FireReaction/Prompt 8.1 검사와 각각의 UID다. 전부 uncommitted이며 commit/amend/reset/push는 하지 않았다.
- 로그/렌더는 `.godot` 로컬 산출물로 Git에 추가하지 않는다. Git global ignore 접근 경고 및 LF→CRLF 안내는 실행 오류와 별개다.

### Fire LOSS 수동 테스트 / 다음 단계

1. F5 직후 U → OFF 표시 확인. 이미 있는 손님은 정상 처리하거나 퇴장을 기다린다. 기존 고객을 지우는 기능은 없다.
2. Can/Appliance 등 상품을 여러 개 진열하고 P로 위험 손님 한 명 생성. 고객 구매분 외 남은 상품이 불에 노출되는지 확인한다.
3. 불 아이콘·진행률 → 상품 소실 + 짧은 손실 표시 → FIRE LOSS 증가를 확인한다. 같은 상품은 한 번만 손실 처리되어야 한다.
4. 같은 조건에서 threshold 전에 소화기를 F로 분사하면 추가 연소/표시가 멈추고 살아남는지 확인한다. 이미 파손된 상품은 복구하지 않는다.
5. Player로 불 접근: 양옆 주황 표시·짧은 밀림·Look/입력 유지. 일반 손님/Drunk/가족은 잠시 물러난 뒤 업무·퇴장을 계속해야 한다.
6. U ON 복귀 후 Fire + O Spill + K Drunk + L 가족 + 계산 병행. Panic→Spill Knockdown은 가능하고 기상/가족 Follow/소화기 사용이 정상이어야 한다.

Known Issues: 단순 바깥 방향 후퇴이므로 벽/상품으로 막힌 화재에서 완전한 우회 탈출을 보장하지 않는다. 공간이 막히면 cooldown 이후 다시 반응할 수 있다. 상품 연소 표시는 공중 Label이라 밀집 배치에서 겹칠 수 있으며 수동 가독성 조절 대상이다. 반응 강도/가속/시간의 손맛은 수동 확인 대기.
**NPC Knockdown Mesh / Collider mismatch**, **Cart Contact Repeated Damage**는 의도적으로 유지하며 최종 Gameplay/Physics Polish에서 재검토한다. Player/NPC Health, Thief 등 새 이벤트는 추가하지 않았다. 수동 테스트가 정상이라면 Prompt 9 Thief + Chase + Stolen Goods로 진행할 수 있다.

## Prompt 8 — Dangerous Customer / Fire / Extinguisher

2026-09-30. 구현 및 신규 자동 검사 완료. 전체 회귀/Main 결과는 아래 검증 기록을 확인한다. 사용자 수동 조작감 검증은 별도다. 작업 시작 시 Git은 clean이었으며 이번 변경은 모두 uncommitted로 유지한다. 이전 절의 dirty 파일 수는 당시 이력이다. 아래 이전 Prompt 7.3의 다음 단계였던 Fire는 이제 구현되었다.

### 구조와 기존 시스템 연결

- `DangerousCustomer`는 `BasicCustomer` 상속. P 개발용 입력 → 기존 CustomerManager 생성/구매 목록/예약/Shopping Points/물리 Pickup/Basket을 그대로 사용한다. 첫 상품 종류 쇼핑 완료 후 `accident_triggered`로 한 번만 화재 생성을 시도하고 `:O !` 표시 및 0.8초 정지 후 쇼핑/계산을 계속한다. 재고가 없으면 기존 품절 퇴장이라 사고가 발생하지 않는다. 화재 수 제한에 막힌 사고를 반복 재시도하지 않는다.
- `FireManager`는 Mart의 `Fires` 자식이다. 아래 방향 ray로 실제 StaticBody 표면과 위쪽 normal을 확인해 FireZone을 생성한다. 수평 Shelf 표면도 가능하다. 별도의 Round Director나 전역 게임 정지 상태가 없다.
- FireZone은 Area3D + 원통 감지 영역 + 발광 원뿔 두 개 + 조명이다. intensity가 성장하면 시각 크기·반경이 증가한다. 자동 소멸 시간은 없으며 진압되면 Area와 Visual을 함께 제거하고 통계는 한 번 증가한다.
- 가연성 판매 상품의 노출을 0.5초 간격으로 누적한다. 여러 불이 겹쳐도 해당 상품에는 최대 intensity 한 개만 적용한다. 누적 heat가 6에 도달하면 기존 `broken` 상태를 설정하고 실제 상품을 제거하며 실제 `price`를 손실에 한 번 더한다. 범위를 벗어나거나 진압하면 열 누적은 멈추되 기존 노출량은 남는다. 이미 sold/broken/삭제 예정인 물체는 제외한다.
- `GrabbableBody.flammable` 기본 true: 현재 3종은 단순 포장재 가연성 프로토타입으로 동일 처리한다. false로 바꾸면 연소/확산 대상에서 제외된다. 빈 product_type인 Mop/소화기는 판매 상품 연소 대상이 아니다. Player Health는 없다.
- intensity 0.55 이상 불 주변 2.6m 이내, 벽에 가리지 않은 가연성 상품이 3초 노출되면 2초마다 최대 한 개의 새 불을 시도한다. 최대 10개, 최소 간격 1.2m로 제한한다. 상품이 없으면 빈 바닥으로 무한 확산하지 않는다. Spread와 상품 피해는 별도 누적이다.
- 연소 상품은 기존 Shelf 실제 Stock/Reservation 검사에서 빠진다. SHOP 이전 예약 상품이 타면 기존 Out of Stock 처리이며 새 예약/판매 시스템은 없다. 이미 Basket에 든 상품은 물리 오브젝트가 없어 화재 손실 대상이 아니다.
- Basic/Drunk/Parent/Child에 1초 간격의 짧은 놀람 표시와 바깥 방향 힘을 적용한다. 몸통 기준 LOS를 검사해 벽 너머 반응을 막는다. Carry/Knockdown 중인 Character에는 추가 반응을 주지 않는다. Child 실패/가족 성공 통계나 NPC Health를 추가하지 않는다. 복잡한 Fire avoidance 경로는 없다.

### Fire Extinguisher / 공통 힘 전달

- 실제 RigidBody3D 소화기는 기존 GrabbableBody의 Grab/Carry/Drop/Charge Throw와 Safe Hold/Break Grace를 그대로 사용한다. weight 3, price 0, product_type 비어 있음, flammable false. 판매되지 않는다. 별도 Combat Damage 콜백은 비활성화하고 실제 물리 충돌은 유지한다.
- Backroom (6.2, 0.45, -1.5), Store (8.2, 0.45, 6)에 2개 배치, `[F]` 표시. F `use_tool`을 들고 누르면 카메라가 가리키는 방향으로 소화기 위치에서 분사한다. 우클릭 Charge Throw는 그대로이며 충전 중에는 분사를 일시 중단한다.
- Cone 범위 + 대상별 시선 ray를 사용한다. 카메라→노즐 차폐도 검사하므로 소화기가 벽 뒤에 걸려도 벽 너머 분사하지 않는다. 반투명 cone으로 분사를 표시하며 중앙 ray 장애물 거리로 표시 길이를 제한한다. 물리 대상의 실제 CollisionShape 중심도 검사하여 바닥에 있는 Cart 원점만 검사하던 누락을 방지한다. 한 tick에 한 body 한 번 힘을 적용한다.
- F 분사 동안 capacity 100에서 초당 8 감소, 최대 약 12.5초. 남은 용량을 소화기 Label에 표시한다. 0이면 분사/진압/힘이 멈추며 빈 통도 Grab/Throw 가능하다. refill은 구현하지 않았다.
- `PhysicsPush.apply()`가 `apply_external_impulse` 인터페이스 또는 RigidBody central impulse를 사용한다. Cart 타입 특례/boost는 없다. 힘은 `90 / (1 + 0.1 * max(mass - 1, 0)) * delta`이며 질량에 따른 가속 차이가 추가로 생긴다. BasicCustomer는 기존 `_push` 상한 3.5를 재사용한다. CarryableCharacter는 impulse에 1.5 반응 배율·최대 6 제한, 0.2초 자력 보행 보정 유예를 주어 AI가 받은 힘을 즉시 지우지 않게 한다. 평소 보행/Carry/Knockdown 경로는 유지한다.
- Player에는 수평 반대 방향 1.5m/s²의 약한 반동만 준다. 직접 Knockdown/피해를 발생시키지 않는다. Spill로 넘어지면 기존 Drop/Charge Cancel에서 분사도 즉시 종료되며 불은 계속 존재한다. Fire와 Spill은 독립적이며 물웅덩이가 자동 소화하지 않는다.

### Inspector 기본값

| 위치 | 변수 / 기본값 |
| --- | --- |
| DangerousCustomer | panic_time 0.8초 |
| FireManager | enable_dangerous_test_spawn true, max_dangerous_customers 2 (일반 손님 총원 제한도 적용) |
| FireManager | max_active_fires 10, minimum_fire_spacing 1.2m |
| FireManager | damage_interval 0.5초, burn_exposure 6 intensity·초 |
| FireManager | spread_interval 2초, spread_exposure 3초, spread_intensity 0.55, spread_distance 2.6m |
| FireZone | intensity 0.3, growth_rate 0.025/초, minimum_radius 0.6m, maximum_radius 1.7m |
| FireExtinguisher | capacity 100, capacity_drain 8/초, spray_range 4m, spray_half_angle 12° |
| FireExtinguisher | extinguish_rate 0.3/초, spray_force 90, push_weight_penalty 0.1, recoil_acceleration 1.5 |
| CarryableCharacter | external_push_response 1.5 |

기본 시작 반경 0.93m, intensity 1까지 약 28초. 다른 요인이 없으면 작은 불은 약 1.1초 집중 분사, 최대 불은 약 3.6초(성장과 동시 계산)에 꺼진다. 이는 수식상 예상이며 실제 조준/이동에 따라 달라진다.

### 생성·수정 파일

- 신규 `scripts/systems/dangerous_customer.gd`, `fire_zone.gd`, `fire_manager.gd`: 특수 손님·불·확산/피해/통계/디버그 생성.
- 신규 `scripts/interaction/fire_extinguisher.gd`, `physics_push.gd`: 소화기 사용·연료·진압·범용 힘 전달.
- 신규 `scenes/interactables/dangerous_customer.tscn`, `fire_zone.tscn`, `fire_extinguisher.tscn`: 씬 및 소화기 Mesh/Collision.
- 수정 `scripts/interaction/grabbable_body.gd`: 가연성 flag. `carryable_character.gd`, `scripts/systems/basic_customer.gd`: 작은 외력 인터페이스.
- 수정 `scripts/systems/mart_graybox.gd`, `project.godot`: FireManager/소화기 배치, P/F Input Map.
- 신규 `tests/prompt8_smoke.gd` 및 스크립트 UID들. 기존 Prompt 검사는 수정하거나 삭제하지 않았다.
- 수정 README/PROJECT_NOTES: 조작법·실제 결과·한계. AGENTS/Skill은 기존 원칙으로 충분하여 수정하지 않았다.

### 검사 이력과 최종 결과

- 임포트 `.godot/p8_import.log`, `p8_import2.log` 종료 0, 오류 없음.
- 최초 `.godot/p8_first.log`: 동적 Node 호출에 Array literal을 넘겨 `Array[RID]` 타입 오류가 발생했다. 생산 코드의 명시적 RID 배열과 검사 fixture의 AccidentManager 타입을 수정했다. 오류로 coroutine이 중단된 최초 실행은 종료시켰으며 성공으로 세지 않는다.
- `.godot/p8_second.log`: 신규 테스트 Player가 (0,3)에서 쇼핑 통로를 막아 화재 손님의 Queue 도착과 종속 결제가 실패했다. 실제 정체 위치를 확인하고 Player fixture를 계산대 쪽으로 옮겼다. 상품/Cart 분사 검사는 collider 중심 검출로 보완했고 NPC가 힘을 즉시 상쇄하던 자력 보행/마찰 문제는 공통 외력 유예와 제한된 배율로 수정했다. 기존 회귀 기준을 낮추지 않았다.
- `.godot/p8_third.log`: 당시 신규 검사 전부 통과. 추가 통합 검사의 `.godot/p8_extended.log`에서는 BasicCustomer 화재 반응 한 항목이 실패했다. `.godot/p8_panic_probe.log`에서 고객 발 원점 Y=-0.000208m, Fire overlap은 있으나 floor가 LOS를 차단함을 확인했다. CharacterBody는 몸통으로 검사하도록 고쳐 바닥 수치 오차를 처리했고 벽 차폐 검사는 유지했다.
- 최종 신규 `.godot/p8_final.log`: **59개 통과, 실패 0, 종료 0, 오류 0**. 단일 사고→실제 Checkout, 성장/확산 상한, 연소 단일 손실, 겹친 불 비누적, 예약 상품 연소 품절, 소화기 실제 입력/진압/고갈/투척/급회전, NPC/Product/Cart 힘, 벽 차폐, Spill Drop, Parent/Child 반응을 검사한다.
- 실제 렌더 `.godot/p8_spray.png`에서 소화기/분사 cone/주황 불/잔량 표시를 확인했다. 이것은 사용자 손맛 수동 검증을 대체하지 않는다.
- 최종 동일 형상 상품의 40 tick 분사 비교: 1kg 이동 3.129m, 8kg 이동 0.00231m. 취객 외력 분리 검사에서는 0.232m 이동했다. 고정 위치 결과를 보장하는 밸런스 수치가 아니라 바닥 마찰/접촉을 포함한 이번 실행 측정이며, 무거운 상품은 거의 움직이지 않는 설정이다.
- 전체 회귀와 Main까지 완료했다. 로그는 `.godot`의 로컬 산출물이며 Git에 추가하지 않는다.

### Prompt 8 최종 검증 결과

**기존 697개 + 신규 59개 = 총 756개 통과.** 최종 전체 회귀 실행에서 실패/재실행 없음. 앞서 기록한 신규 개발 중 실패를 수정한 뒤 순차 실행한 결과다.

| Prompt | 통과 |
| --- | ---: |
| 0 / 1 / 1.1 | 22 / 48 / 40 |
| 2 / 2.1 | 41 / 28 |
| 3 / 3.1 | 32 / 29 |
| 4 | 54 |
| 5 / 5.1 / 5.2 | 33 / 36 / 57 |
| 6 / 6.1 / 6.2 | 40 / 35 / 48 |
| 7 / 7.1 / 7.2 / 7.3 | 55 / 57 / 26 / 16 |
| 8 | 59 |

- 최종 `.godot/p8_final.log` 및 `.godot/p8_regression_<번호>.log` 전부 종료 0, `FAIL:`/`SCRIPT ERROR`/`ERROR:` 0건. 입력 검사는 창 모드 `--fixed-fps 60` 순차 실행했다.
- `.godot/p8_main.log`: Main headless 7200 tick / 120초 시뮬레이션, 종료 0, 오류 없음. 배송 6개 도착 및 Left Behind 6개 출발 로그 확인.
- 재실행 명령: `& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --path . --fixed-fps 60 --script res://tests/prompt8_smoke.gd --quit-after 16000`. 기존 검사도 같은 방식으로 번호를 바꿔 실행한다. Main은 `--headless --path . --fixed-fps 60 --quit-after 7200`.
- `git diff --check` 통과. tracked 수정 7개 / 신규 15개(UID 포함), 모두 uncommitted. commit/amend/reset/push는 하지 않았다. Git의 global ignore 파일 접근 경고와 LF→CRLF 안내는 Godot 실행 오류와 별개다.

### 수동 확인 / Known Issues / 다음 작업

1. F5 → 3종 상품 진열 → P. 첫 Pickup 후 불이 한 번 생기고 손님이 잠시 놀란 뒤 계산으로 오는지 확인한다. 품절/입구 막힘/최대 손님 수에서는 생성 또는 사고가 없을 수 있다.
2. 불을 방치하여 크기/상품 노출/제한 확산과 LOSS를 확인한다. 같은 상품 가격이 중복 증가하면 안 된다. 실제 상품이 Shelf에서 사라져 Stock도 줄어야 한다.
3. 빨간 소화기를 좌클릭으로 집고 F로 진압한다. 벽 뒤는 진압되지 않아야 한다. 잔량 소진 후 효과 중단, 빈 통 Drop/Charge Throw, 급회전 Hold를 확인한다.
4. Can/Watermelon/Appliance, Drunk/일반 손님, 빈 Cart에 분사해 질량별 반응을 비교한다. 강한 공격이나 전용 Cart Rocket은 없다.
5. O로 Spill, K 취객, L 가족과 함께 P 화재를 만들고 계산·배송·청소를 병행한다. 소화기 보유 중 넘어지면 Backward Fall+Drop+분사 중단, 기상 후 회수 가능, 화재는 계속 유지되는지 확인한다.
6. 수동 검증 대기: 분사 조준과 원뿔 가독성, 제한 용량의 여유, 불 성장/확산 속도, 여러 손님이 막힌 공간에서의 Panic 이동은 실제 플레이로 조절할 수 있다. NPC는 짧은 밀림만 사용하며 완전한 우회 AI가 없어 불에서 항상 완벽히 탈출한다고 보장하지 않는다.

의도적으로 유지한 최종 점검 항목: **NPC Knockdown Mesh / upright Collider mismatch**(Final Polish), **Cart Contact Repeated Damage**(전체 전투 이후 Final Gameplay/Physics). 이번 작업에서 수정하지 않았다.
소화기 refill, Fire/Water 자동 상호작용, Player Health, Electrical Hazard, Cart Rocket, Thief, Tourist Bus, 무기 진행/보스/멀티플레이/정산은 미구현이다. 수동 테스트가 정상이라면 Prompt 9 Thief + Chase + Stolen Goods에 기존 Customer/Basket/외력 구조를 재사용할 준비가 된 상태이며 Thief 코드는 추가하지 않았다.

## Prompt 7.3 — First-person Backward Fall Rework (구현·자동 검사 완료, 수동 손맛 확인 대기)

2026-09-30. 사용자 수동 테스트에서 7.2 기능은 정상이지만 옆으로 쓰러지는 방향이 의도와 달랐다. `KnockdownState._player_pose()`의 주 회전을 local Z Roll에서 **local X Pitch +75°**로 바꿨다. 이동 방향에 따른 좌우 `_fall_side` 선택은 제거했다. 기존 dirty 상태(tracked 수정 15 / untracked 21)를 보존하고 추가 작업했다. 아래 이전 절은 당시 기록이며 현재 Player 연출은 이 절을 우선한다.

### Camera Pose / Direction / Look

- FALLING: 0.2초 smoothstep 보간, 높이 최대 1.1m 하강 + Pitch 75° 증가. 기본 Roll 0°. DOWN 0.8초 동안 유지. STANDING_UP 0.4초에 높이와 visual offset을 원래 값으로 복구한다.
- 부호 검증: 실제 Camera `-global_basis.z`의 위쪽 성분이 0.9를 넘고, 전방 ray가 테스트용 천장에 맞는지 검사했다. `.godot/p73_backward_down.png` 실제 렌더에서 천장과 보를 위로 바라보고 화면이 옆으로 눕지 않는 것을 확인했다. 천장/보는 검사 씬에만 추가한 fixture이며 Mart에 새 에셋/구조를 넣지 않았다.
- Player 몸 yaw / Head mouse pitch는 그대로 두고 자식 Camera에 독립적인 visual Pitch/Roll을 적용한다. 현재 Look을 초기화하거나 덮어쓰지 않으며, 기상 후 마지막 Look 방향을 유지한다. 약간의 마우스 입력으로 누운 offset이 사라지지 않는다.
- A/D 이동으로 들어와도 동일 Backward pose다. 기존 수평 속도 방향의 slip boost 1.2m/s, 최대 수평 속도 6.5m/s, 감속 5m/s²는 그대로여서 발은 진행 방향으로 짧게 미끄러진다. 새 힘/이동 시스템을 추가하지 않았다.
- 기존 바닥 ray / floor margin 0.18m / upright capsule 중심선 수직 하강을 재사용한다. 기본 Eye 1.6m → 약 0.5m. 카메라를 옆/뒤로 밀어 넣지 않으며 Player collider와 NPC 표현/AI/Collider도 변경하지 않았다.

### 조절 값

| 변수 | 기본값 |
| --- | ---: |
| fall_camera_pitch_degrees | 75° (신규, 뒤로 젖히는 양의 X 회전) |
| fall_camera_roll_degrees | 0° (이전 75°) |
| fall_camera_drop | 1.1m |
| fall_camera_floor_margin | 0.18m |
| fall_down_time / knockdown_duration / stand_up_time | 0.2 / 0.8 / 0.4초 |
| slip_speed_boost / max_slip_speed / down_braking | 기존 1.2 / 6.5 / 5 |
| slip_immunity_time | 기존 1.3초 |

### 변경 파일 / 검사 계약

- `scripts/interaction/knockdown_state.gd`: Player camera Pitch 추가, 큰 Roll 기본값/좌우 선택 제거. 그 외 NPC/물리/Drop 경로는 그대로.
- `tests/prompt7_3_smoke.gd`와 UID: 정면·좌우 실제 Spill 진입, 방향/천장 ray/렌더, 낮은 시점, DOWN pose, Look/복구/반복 검사 16개.
- `tests/prompt7_1_smoke.gd`: 기존 시각 회전 검사의 축을 Pitch로 변경하고 복구 때 모든 visual 회전이 0인지 확인한다. 기존 57개 유지.
- `tests/prompt7_2_smoke.gd`: 사용자 요구로 폐기한 75° Side Roll/좌우 방향 assertion을 75° backward Pitch/Side Roll 없음으로 대체했다. 65° 이상, 높이, 보간, Look 독립, 반복 복구, Wall/Floor 안전의 동일 기준과 기존 26개 검사를 유지한다. 이전 렌더를 덮어쓰지 않도록 새 이미지 경로를 사용한다. 통과를 위해 threshold를 낮추지 않았다.
- `README.md`, 이 문서: 현재 표현/검사/수동 확인 갱신. Agent/Skill이나 다른 gameplay 코드는 변경하지 않았다.
- 신규 검사 `.godot/p73_new.log`: 16개 통과, 종료 0. 전체 회귀 결과는 아래 최종 검증 기록을 참고한다. 실제 렌더 방향은 확인했으나 사용자 수동 손맛을 대신 검증했다고 주장하지 않는다.

### Prompt 7.3 최종 자동 검사 결과

**기존 681개 + 신규 16개 = 총 697개 통과.** 이번 실행에서 검사 실패/재실행 없음. 모든 창 테스트는 `--fixed-fps 60`으로 순차 실행했다.

| Prompt | 통과 |
| --- | ---: |
| 0 / 1 / 1.1 | 22 / 48 / 40 |
| 2 / 2.1 | 41 / 28 |
| 3 / 3.1 | 32 / 29 |
| 4 | 54 |
| 5 / 5.1 / 5.2 | 33 / 36 / 57 |
| 6 / 6.1 / 6.2 | 40 / 35 / 48 |
| 7 / 7.1 / 7.2 / 7.3 | 55 / 57 / 26 / 16 |

- 기존 회귀 로그 `.godot/p73_regression_<번호>.log`(소수점 대신 `_`), 신규 `.godot/p73_new.log`: 전부 종료 코드 0, `ERROR:`/`SCRIPT ERROR`/`FAIL:` 없음.
- 임포트 `.godot/p73_import.log` 및 Main 120초 시뮬레이션 `.godot/p73_main.log`도 종료 0/오류 없음. 기존 배송 도착/출발까지 확인했다.
- 명령 예: `& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --path . --fixed-fps 60 --script res://tests/prompt7_3_smoke.gd --quit-after 3000`.
- 이전 Prompt의 실패/재검사 기록은 과거 이력으로 그대로 보존한다. 현재 각종 physics/NPC 검사를 새로 실행한 결과다.
- `git diff --check` 통과. 이전 변경을 포함한 전체 working tree는 tracked 수정 15 / untracked 23개. 이번 신규 파일은 7.3 검사와 UID이며 자동 commit/amend/reset/push는 하지 않았다.

### 수동 검증 / Deferred Final Checks

1. F5 → 상품 진열 → O로 사고 손님/Spill 생성. 정면 이동으로 중앙 진입: 발은 짧게 미끄러지고 시점은 낮아지며 뒤로 젖혀져 위쪽을 봐야 한다.
2. A/D 진입에서도 같은 Backward pose인지 확인한다. 큰 좌우 Roll이 발생하면 안 된다.
3. DOWN 중 둘러보기, 기상 후 마지막 Look 유지, 반복 넘어짐 후 잔여 offset 없음 확인. 극단적인 기존 Look pitch와 visual pitch가 합쳐지는 상황의 가독성도 수동 비교한다.
4. Shelf/Wall/좁은 통로에서 바닥·벽 관통 없이 기상하는지 확인한다. 상품/Child/Cart 보유 중에는 기존 Drop/Release/Charge Cancel이 발생해야 한다.

다음 항목은 **의도적으로 수정하지 않았으며 전체 기능 구현 이후 반드시 재검토**한다:

- **NPC Knockdown Mesh / Collider mismatch:** NPC는 Mesh만 눕고 collider는 upright. Final Physics/Polish TODO.
- **Cart Contact Repeated Damage:** 밀착 반복 피해. 전투 완성 후 Final Gameplay/Physics TODO.

수동 테스트가 정상이면 Prompt 8 Dangerous Customer + Fire + Fire Extinguisher를 진행할 준비가 되어 있다. 이번에 Fire나 새 Gameplay 콘텐츠는 구현하지 않는다. 변경은 uncommitted로 유지하며 commit/amend/reset/push하지 않는다.

## Prompt 7.2 — First-person Fall Presentation Polish (구현·자동 검사 완료, 수동 손맛 확인 대기)

2026-09-30 작업. 사용자 수동 확인으로 Prompt 7.1 Knockdown과 NPC 표현은 정상이나 Player의 0.65m 하강/15° Roll은 앉았다 일어나는 느낌이었다. Player 카메라 표현만 강화했다. 기존 uncommitted 변경(tracked 15 / untracked 19)을 보존했다. 아래의 이전 Prompt 기록은 당시 동작이며 현재 카메라 값은 이 절을 우선한다.

### Player Camera Pose / Look

- 공통 `KnockdownState`의 **Player 분기만** 수정. Head는 높이와 기존 mouse pitch를 담당하고 자식 `Head/Camera3D`에는 넘어짐 local Roll만 적용한다. Player yaw와 mouse pitch를 덮어쓰지 않는다. 노드 경로/씬 구조를 바꾸지 않아 기존 Interaction 참조도 그대로다. 추가 강제 pitch 연출은 사용하지 않는다.
- FALLING 0.2초: smoothstep 보간으로 Head를 최대 1.1m 낮추고 Camera를 75° 눕힌다. 기본 Eye 1.6m → 바닥 위 약 0.5m. DOWN 0.8초: 누운 높이/Roll 유지. STANDING_UP 0.4초: 같은 곡선으로 원래 높이/Roll 복구. 기존 기상 후 면역 1.3초 유지.
- 진입 방향과 Player right 벡터 내적이 ±0.2m/s를 넘으면 해당 옆 방향으로 눕는다. 애매한 전진/정지 방향은 일정한 기본 방향으로 눕는다. 방향은 넘어짐 시작 때 한 번 정하며 마우스를 움직였다고 좌우가 뒤집히지 않는다.
- 카메라는 옆/앞으로 이동시키지 않고 upright capsule의 중심선에서 수직으로만 낮춘다. 따라서 근처 벽 방향으로 카메라를 밀어 넣지 않는다. near plane은 기존 0.05m, Player 반경 0.35m 유지.
- 정상 Eye 위치에서 바닥 방향 ray(자신 제외)로 확인해 표면 위 최소 `fall_camera_floor_margin=0.18m`를 확보한다. 하강값을 과도하게 올려도 Player 발 기준 margin으로도 제한한다. mouse pitch와 관계없이 하강은 upright body 좌표에서 적용한다. 복잡한 전역 Camera Collision 시스템은 추가하지 않았다.
- 복구 시 Head 높이 및 Camera local 회전을 저장한 기본값으로 돌린다. 사용자가 넘어져 있는 동안 변경한 look pitch/yaw는 유지한다. 반복 넘어짐에서 offset을 누적하지 않는다.

### 조절 값 / 범위

`KnockdownState` 런타임 Component의 Remote Inspector 또는 스크립트 기본값:

| 변수 | 기본값 |
| --- | ---: |
| fall_camera_drop | 1.1m |
| fall_camera_roll_degrees | 75° |
| fall_camera_floor_margin | 0.18m (최소 안전 제한 0.1m) |
| fall_down_time | 0.2초 |
| knockdown_duration | 0.8초 |
| stand_up_time | 0.4초 |
| slip_immunity_time | 기존 1.3초 |

기존 `camera_drop`/`camera_roll_degrees`는 명확한 Player 전용 이름으로 변경했다. NPC tilt/AI pause/Collider, Spill 조건, Held Drop/Cart Release/Charge Cancel, Product/Cart Wet Physics, Mop Cleaning은 수정하지 않았다. Player 몸과 Capsule도 upright를 유지하여 floor detection과 이동/상호작용 복구를 보존한다.

### 파일 / 검사

- `scripts/interaction/knockdown_state.gd`: Player 전용 보간/바닥 여유/독립 Camera Roll.
- `tests/prompt7_2_smoke.gd` 및 UID: 실제 Spill에서 강한 하강·Roll, DOWN 유지, mouse pitch/yaw 독립, 보간, 좌우 방향, 반복 복구, 과도한 하강 설정 제한, 벽 근처 안전 검사.
- `tests/prompt7_1_smoke.gd`: 카메라 Roll의 소유자가 Head에서 Camera로 분리되어 시각적 Roll/복구 assertion 2개의 참조만 Camera로 변경했다. 기존 57개 계약과 threshold는 유지한다. 나머지 기존 테스트는 수정하지 않는다.
- `README.md`: 새 Player 표현 및 검사 명령. Agent/Skill은 변경하지 않았다.
- 신규 검사 `.godot/p72_new.log`: 26개 통과/종료 0. `.godot/p72_down.png` 렌더에서 낮은 시점과 약 75°의 측면 자세를 확인했다. 실제 사용자 조작감/멀미 여부는 수동 확인 대기다.

### Prompt 7.2 최종 검증 결과

**기존 655개 + 신규 26개 = 681개 통과.** 모든 창 검사는 순차 실행했으며 `--fixed-fps 60` 사용. 최종 통과 로그에서 `ERROR:`/`SCRIPT ERROR`/`FAIL:` 없음.

| Prompt | 통과 |
| --- | ---: |
| 0 / 1 / 1.1 | 22 / 48 / 40 |
| 2 / 2.1 | 41 / 28 |
| 3 / 3.1 | 32 / 29 |
| 4 | 54 |
| 5 / 5.1 / 5.2 | 33 / 36 / 57 |
| 6 / 6.1 / 6.2 | 40 / 35 / 48 |
| 7 / 7.1 / 7.2 | 55 / 57 / 26 |

- 기존 검사의 통과 로그: `.godot/p72_regression_<번호>.log` (소수점은 `_`). **7.1의 최종 통과 로그는 `.godot/p72_isolated_7_1.log`**. 신규 `.godot/p72_new.log`. 각 종료 코드 0.
- 임포트 `.godot/p72_import.log`, Main 120초 시뮬레이션 `.godot/p72_main.log` 모두 종료 0/오류 없음. Main에서 배송 도착/출발까지 확인했다.
- 실패 이력: 최초 전체 실행의 `.godot/p72_regression_7_1.log`는 PAY ray와 그에 따른 판매 확인 2개 실패(55개 통과). 해당 시점의 포커스/충돌 대상 기록이 없어 원인을 단정하지 않는다.
- 조사: `.godot/p72_pay_probe.gd/.log`로 원래 7.1을 상속하고 동일 assertion을 실행하면서 focus, Head/Camera transform, 실제 ray collider를 추가 기록했다. Scan/Pay 모두 mouse capture=2, operator=true, 실제 Scanner/Payment collider에 명중했고 Player Knockdown은 UPRIGHT, Head 높이는 1.6m, 카메라 위치는 원점이었다. 잔여 Fall offset은 없었다. 진단 실행 57개 통과/종료 0. 게임 코드나 검사 기준을 더 바꾸지 않은 원래 검사 단독 실행도 57개 통과했다. 실패를 삭제하거나 최초부터 모두 통과했다고 보고하지 않는다.
- 기존 카트/상품/진열/계산/취객/미아/가족 퇴장/Spill/Mop 회귀도 통과했다. 카메라 연출 외의 추가 gameplay 수정은 없었다.
- 실행 예: `& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --path . --fixed-fps 60 --script res://tests/prompt7_2_smoke.gd --quit-after 3000`.
- `git diff --check` 통과. 전체 working tree는 이전 Prompt 변경을 포함해 tracked 수정 15 / untracked 21개. 이번 신규는 Prompt 7.2 검사와 UID이며 commit/amend/reset/push하지 않았다.

### 수동 확인 / Deferred Final Checks

1. F5, 상품 진열 후 O로 사고 손님/Spill 생성. 중앙을 빠르게 지나 누운 화면 → 약 0.8초 유지 → 부드러운 기상을 확인한다.
2. DOWN 중 마우스를 위아래/좌우로 움직여도 화면이 갑자기 upright가 되지 않고 바닥 내부가 보이지 않는지 확인한다.
3. Shelf/Wall 근처에서도 반복한다. 넘어짐은 시각 효과이므로 몸의 벽 충돌은 그대로여야 한다.
4. 상품/미아 Carry 및 Cart Grab 상태에서 각각 Fall → Drop/Release/Charge 취소 → 기상 후 재Grab을 확인한다.
5. 면역 뒤 다시 넘어져도 높이/Roll이 쌓이지 않는지 확인한다. 75°가 실제 플레이에서 과하면 Inspector로 줄여 비교한다.

**전체 기능 구현 이후 반드시 재검토할 항목:**

- **NPC Knockdown Mesh ↔ Collider mismatch:** 현재 Mesh만 약 80° 눕고 실제 Collider는 upright다. 이번에는 의도적으로 유지했다. Final Physics/Polish에서 전용 shape, 회전/전환, ragdoll 또는 현 방식 유지 중 플레이 테스트로 결정한다.
- **Cart Contact Repeated Damage:** 밀착해 비빌 때 반복 피해가 발생하는 현상을 의도적으로 유지했다. 전체 전투 구현 후 Final Gameplay/Physics 점검에서 재평가한다.

수동 확인이 정상이라면 Prompt 8 Dangerous Customer + Fire + Fire Extinguisher로 진행할 준비가 되어 있다. 이번에 Fire나 새로운 gameplay 시스템을 구현하지 않았다. 변경은 uncommitted로 유지한다.

## Prompt 7.1 — Character Slip Knockdown + Recovery (구현·자동 검사 완료, 수동 조작감 확인 대기)

Prompt 7의 캐릭터 관성만으로 약했던 피드백을 명확한 넘어짐/기상으로 확장했다. 이전 Prompt 7의 tracked 수정 11개 / untracked 15개를 그대로 보존하고 그 위에 작업했다. 상품/카트 wet physics와 카트 밀착 반복 Damage는 수정하지 않았다. 새로운 고객 종류, 화재, 무기, 체력, ragdoll은 추가하지 않았다.

### 공통 Knockdown 구조 / Trigger

- `scripts/interaction/knockdown_state.gd`: 작은 Character 전용 Node. 각 Player / BasicCustomer / CarryableCharacter의 `_ready()`에서 `Knockdown` 자식으로 연결한다. Basic에서 Accident/LostParent, Carryable에서 Drunk/LostChild로 재사용한다. 상품/Cart에는 이 Component를 붙이지 않는다.
- 상태: UPRIGHT → FALLING → DOWN → STANDING_UP → IMMUNE → UPRIGHT. 한 캐릭터에 하나만 존재하고 active/immunity 중 다시 시작할 수 없다. `try_start(direction)`는 공통 중단 시작점이며 현재 실제 gameplay 호출자는 Spill 판정뿐이다. 미래 전투를 구현한 것은 아니다.
- 각 Character가 정상 이동/AI보다 먼저 `tick(delta)`를 호출한다. 기존 SlipState의 현재 영역 weak reference를 읽고 **바닥 접촉 + 활성화된 Spill Core 내부 + 충분한 수평 속도**를 만족하면 시작한다. 무작위 확률은 없다.
- Spill `core_ratio=0.7`: 기본 반경 1.5m의 안쪽 1.05m. 청소로 줄어드는 실제 반경과 함께 줄어든다. Body 가장자리가 아닌 중심의 수평 위치를 비교한다. `activation_delay=0.3초` 후부터 넘어짐 판정이 켜지며, 기존 저마찰 modifier는 즉시 적용한다.
- Carry 중 Character, 공중 Character, Cart 위에 지지된 CarryableCharacter는 별도 Spill Fall을 시작하지 않는다. 여러 Spill에서도 이미 발생한 넘어짐을 중첩하지 않는다. Spill 삭제 시 신규 Trigger는 즉시 없어지지만 이미 시작한 짧은 기상은 끝까지 진행한다.

### Player / Held 대상

- 넘어짐 시작 신호에서 기존 `Interaction.drop_held()`를 호출한다. Product/Character/Cart 모두 기존 소유권·충돌 예외 해제 경로를 사용하고 Charge도 취소한다. 강제 Drop이므로 미아의 명시적 Drop 인계 콜백을 실행하지 않는다.
- Fall 중 WASD/Jump/Grab/Throw/계산 입력은 제한하지만 mouse look/Esc는 유지한다. 기존 Head의 Y와 roll만 수정하여 사용자가 보는 pitch/yaw를 덮어쓰지 않는다. 약 0.65m 낮아지고 roll 15° 뒤 원래 높이/roll로 돌아온다.
- 진행 방향 속도 +1.2m/s(수평 상한 6.5m/s), 이후 5m/s²로 짧게 감속한다. 중력과 CharacterBody move_and_slide는 계속 사용한다. Collider를 눕히거나 Transform을 순간이동시키지 않아 Wall 충돌이 유지된다.
- 총 Fall/Down/Stand 약 1.4초, 이어서 1.3초 재넘어짐 면역. 기상이 끝나면 이동과 상호작용은 바로 가능하다. Product/Character를 다시 잡으려면 좌클릭한다.

### NPC / 상태 보존

- NPC의 실제 Capsule은 그대로 두고 Mesh만 약 80° 기울인다. Capsule Mesh의 height/radius로 외형 높이를 낮춰 작은 미아도 바닥 안으로 과도하게 들어가지 않게 한다. 아이콘/Family Symbol은 계속 읽을 수 있다.
- BasicCustomer는 넘어지는 동안 경로 진행·쇼핑 타이머·Queue Patience·Scan wait를 보존하고 AI 이동을 건너뛴다. Rigidbody Character는 중력/접촉을 유지하면서 자율 보행만 쉬고 현재 수평 속도를 감속한다.
- Drunk의 방향 갱신/흔들림/능동 상품 파손은 잠시 쉬며 기상 후 Wander를 재개한다. LostChild Follow/LostParent Exit는 기존 목적지를 그대로 사용한다. Prompt 6.1 가족 충돌 예외는 제거하지 않는다.
- 다운된 일반 손님에게는 Scan/Pay를 진행하지 않는다. 복구 후 기존 Basket·예약·계산 흐름을 그대로 사용한다. 사고 손님은 자기 Spill에서 당황한 뒤 움직이다 넘어질 수 있고, 복구 후 추가 사고 없이 Checkout으로 간다.
- 다운된 CarryableCharacter도 기존 Grab으로 들 수 있다. 들 때 외형을 복구하고 면역 상태로 전환하여 Carry 도중 이중 이동 제어가 생기지 않게 한다. 기존 Drunk 85% / Child 98% 운반 배율과 Character Throw 금지는 유지한다.

### 조절 값 (Knockdown Component Inspector)

| 변수 | 기본값 |
| --- | ---: |
| minimum_fall_speed | Player/Basic/Accident/Child 1.5m/s; Drunk 1.2; Parent 1.3 |
| fall_down_time | 0.2초 |
| knockdown_duration | 0.8초 |
| stand_up_time | 0.4초 |
| slip_immunity_time | 1.3초 |
| slip_speed_boost / max_slip_speed | 1.2 / 6.5m/s |
| down_braking | 5m/s² |
| camera_drop / camera_roll_degrees | 0.65m / 15° |
| npc_tilt_degrees | 80° |
| Spill core_ratio / activation_delay | 0.7 / 0.3초 |

Parent의 기존 보행 속도 1.5m/s에서도 발생하도록 조건을 1.3으로, 취객은 더 쉽게 넘어지도록 1.2로 초기화한다. 런타임 생성 Component는 Remote Inspector 또는 스크립트 기본값에서 조정한다.

### 파일 / 검사

- 추가: `scripts/interaction/knockdown_state.gd`/UID, `tests/prompt7_1_smoke.gd`/UID.
- 수정: `spill_zone.gd` Core/활성화; `player_controller.gd` 카메라·이동; `player_interaction.gd` 넘어짐 중 입력 차단; `carryable_character.gd` 공통 물리 중단; `basic_customer.gd`, `drunk_customer.gd`, `lost_child.gd`, `lost_parent.gd`, `accident_customer.gd`의 AI/외형 일시 정지; `checkout.gd` 다운된 Player/고객 처리 제한.
- 회귀 보존 수정: `grabbable_body.gd`에서 Cart Bomb 상품의 실제 이동 속도 기록을 보정했다. 아래 진단 근거를 참고한다. 상품 물리 힘/마찰/가격/피해 공식과 Cart 본체 반복 피해는 바꾸지 않았다.
- `tests/prompt7_smoke.gd`: 기존 저마찰/관성/밀침 수치만 분리해 검사하는 fixture Spill에 활성화 지연 60초를 지정했다. 기존 55개 assertion은 유지한다. 실제 사고 손님 시나리오는 기본 Spill로 검사한다. 신규 7.1은 기본 0.3초 활성화와 실제 넘어짐을 검사한다. 다른 기존 테스트는 변경하지 않는다.
- 초기 `.godot/p71_first.log`: 기본 신규 흐름 오류 없이 통과. 이후 Wall 충돌, Queue/Patience 중단, 실제 Spill 위의 가족 퇴장 검사를 추가했다. 최종 전체 결과는 아래에 기록한다.
- 회귀 `.godot/p71_final_prompt2.log`(고정 간격), `p71_verified_prompt2.log`(기존 일반 실행)에서 Cart Bomb의 차체 타격/적재물 이탈은 통과했지만 개별 상품 피해는 0건이었다. 단순 시간 간격 문제로 단정하지 않고 `.godot/p71_bomb_probe.gd/.log`로 접촉 순서와 실제 속도를 기록했다.
- 진단에서 상품이 약 5m/s로 타깃 앞을 통과하는데 `_incoming_velocity`는 약 0.0008m/s인 사례를 확인했다. 기존 코드는 **접촉 0개일 때만** 속도를 기록하므로 계속 바구니/다른 적재물과 접촉 중인 상품은 Launch 전 정지 속도를 보존했다. 진단 실행에서는 일부 상품이 접촉에서 떨어져 기록이 갱신되어 3건 타격도 발생했다. 해당 진단 자체는 다른 적재 카트 손잡이 선택 1건과 그에 따른 Full Launch 1건이 실패했으므로 전체 통과 로그로 사용하지 않는다.
- 최소 수정: Cart source 및 다른 Grabbable과의 기존 무시 대상 내부 접촉 중에도 최신 물리 속도/최근 3 tick을 기록한다. 실제 외부 충돌 때는 기존 기록을 유지해 CCD 속도 손실을 피한다. 일반 Throw의 접촉 규칙, 첫 외부 충돌 1회 소모, 피해 공식/상한은 유지한다. 오래된 Launch 최고 속도를 사용하거나 피해 임계치를 낮추지 않았다. 기존 Prompt 2 assertion/fixture는 변경하지 않았다.
- 실제 렌더 `.godot/p71_player_down.png`에서 낮아진 시점과 약 15° 기울기를, `p71_npc_down.png`에서 약 80° 누운 NPC 외형을 확인했다. 수동 조작감 테스트를 수행했다고 주장하지 않는다.

### 최종 자동 검사 결과 (2026-09-29)

기존 598개 + 신규 57개 = **655개 통과**. 아래는 각 검사의 최종 통과 로그이며, 최초 실행부터 모두 통과했다는 뜻은 아니다. 실패/진단 로그도 `.godot`에 보존했다. 입력 검사는 실제 창에서 순차 실행했고, 3.1/7/7.1 최종 검사는 `--fixed-fps 60`을 사용했다.

| Prompt | 통과 | `.godot/` 최종 로그 |
| --- | ---: | --- |
| 0 | 22 | p71_final_prompt0.log |
| 1 | 48 | p71_complete_prompt1.log |
| 1.1 | 40 | p71_complete_prompt1_1.log |
| 2 | 41 | p71_complete_prompt2.log |
| 2.1 | 28 | p71_complete_prompt2_1.log |
| 3 | 32 | p71_verified_prompt3.log |
| 3.1 | 29 | p71_isolated_prompt3_1.log |
| 4 | 54 | p71_verified_prompt4.log |
| 5 | 33 | p71_verified_prompt5.log |
| 5.1 | 36 | p71_verified_prompt5_1.log |
| 5.2 | 57 | p71_verified_prompt5_2.log |
| 6 | 40 | p71_verified_prompt6.log |
| 6.1 | 35 | p71_verified_prompt6_1.log |
| 6.2 | 48 | p71_last_prompt6_2.log |
| 7 | 55 | p71_isolated_prompt7.log |
| 7.1 | 57 | p71_last_prompt7_1.log |

- 최종 위 로그에서 `ERROR:` / `SCRIPT ERROR` / `FAIL:` 없음. 임포트 `p71_complete_import.log` 및 Main 120초 시뮬레이션 `p71_complete_main.log`도 종료 코드 0, 오류 없음. Main에서는 배송 도착/출발까지 진행했다.
- Cart Bomb 회귀 수정 뒤 기존 Prompt 1/1.1/2/2.1, 3.1, 6.2, 7, 7.1을 재검사했다. Prompt 2에서는 적재 5개, 이탈 2개, 개별 상품 타격 3회, 차체 타격 1회를 기록했다.
- 추가 실행 `p71_complete_prompt3_1.log`에서 적재 카트 회전/Grab 관련 6개 실패가 있었다. 진단 `p71_control_probe.log`는 창 `FOCUS EXIT`, mouse capture 0, Grab 해제, fall_count 0을 실제 기록했다. 진단 실행의 총 10개 실패 중 앞부분 회전 산포까지 모두 포커스 탓이라고 단정하지 않는다. 게임 제어/회귀 assertion은 변경하지 않고 단독 실행 `p71_isolated_prompt3_1.log`에서 29개 통과를 확인했다.
- `p71_last_prompt7.log`는 Scan/Pay 조준 실패 3개와 그에 따른 판매/퇴장 실패 2개가 있었다. 해당 실행에는 포커스 계측이 없어 포커스 문제라고 확정하지 않는다. `aimed_action()`의 마우스 캡처/조준 조건과 실제 GUI 의존성을 확인하고, 코드/검사 조건을 바꾸지 않은 단독 실행 `p71_isolated_prompt7.log`에서 55개 통과했다. 입력 검사 중 Alt+Tab이나 실제 마우스 조작을 섞지 않는다.
- 재실행 명령 예: `& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --path . --fixed-fps 60 --script res://tests/prompt7_1_smoke.gd --quit-after 16000`. Headless는 임포트/Main에 사용하며 실제 입력 검사를 대체하지 않는다.
- `git diff --check` 통과. 현재 전체 작업 트리는 이전 Prompt 7 변경을 포함해 tracked 수정 15개 / untracked 19개이며 commit/amend/reset/push하지 않았다. 이 중 이번 신규 파일은 KnockdownState 및 Prompt 7.1 검사와 각각의 UID다. 기존 Prompt 7 파일 일부에도 통합 수정이 들어갔다.

### 수동 확인 / Known Issues / 다음 단계

1. 상품을 진열하고 O로 사고 손님 생성. Spill 가장자리를 느리게 스치기와 중앙을 빠르게 걷기를 비교한다.
2. 중앙 진입 시 짧은 미끄러짐·낮은 카메라·기울기·이동/점프 제한과 mouse look 유지를 확인한다. 약 1.4초 후 복귀, 1.3초 면역 중 빠져나갈 수 있어야 한다.
3. Product Charge / Cart Grab / L 미아 Carry 각각에서 넘어져 Drop·Release·Charge 취소가 되는지 확인한다. 기상 후 다시 잡고 업무를 계속한다.
4. K 취객의 Fall/기상/Wander, 일반 손님의 쇼핑/Queue 복구, 재회 가족의 Fall 후 Follow/Exit를 확인한다.
5. Mop을 들고 제자리에 서서 머리를 움직여 청소한다. Spill 삭제 뒤 같은 바닥에서 넘어지지 않는지 확인한다. Product/Cart는 계속 slide-only다.

- **Cart Contact Repeated Damage 유지.** 이번에도 수정하지 않았다.
- NPC는 시각적 넘어짐으로, 실제 upright Capsule은 유지된다. 외형과 피격/접촉 공간이 완전히 일치하는 ragdoll이 아니다. 통로를 잠깐 막을 수 있으며 기존 실제 장애물에 의한 경로 정체는 남는다.
- 카메라 높이·roll·넘어짐 속도와 기간은 실제 사용자 손맛 확인이 필요하다. 입력 검사는 실제 창에서 순차 실행하며, Prompt 3.1의 기존 시간 간격 민감성 때문에 해당 검사는 `--fixed-fps 60`을 사용한다. 신규 7.1도 같은 고정 간격으로 상태 기간을 검사한다.
- 다음 Prompt 8에서는 기존 고객/물리 도구/환경 영역 구조로 Dangerous Customer + Fire + Fire Extinguisher를 확장할 준비만 되어 있다. 이번에 화재·새 특수 손님·체력·전투·ragdoll을 추가하지 않았다.

## Prompt 7 — Accident Customer / Spill / Slippery Floor / Mop (구현·자동 검증 완료)

현재 구현은 아래와 같다. 이전 절은 각 Prompt 당시의 이력이며, 새 기본 동작은 이 절을 우선한다. 작업 시작 시 Git은 clean이었다. Commit/amend/reset/push는 하지 않으며 사용자가 수동 확인 후 commit한다. Agent/Skill 지침은 그대로 유지했다.

### 구조와 실제 플레이 흐름

- `AccidentCustomer extends BasicCustomer`: 기존 Purchase List / Shopping Points / 실제 Pickup / Basket / Queue / Scan / Pay / Patience / Exit를 상속한다. 첫 상품 종류의 SHOP 완료 후 바닥에 Spill을 한 번 만들고 `:O !` 표정으로 0.8초 당황한 뒤 계속 진행한다. 상품은 여전히 NPC에 붙이지 않는다. `accident_triggered`로 반복 사고를 막는다.
- `AccidentManager`: Mart의 `Accidents` 노드. 개발용 **O / debug_spawn_accident**로 생성하며 동시에 최대 2명. 일반 Customers의 최대 인원 및 입구 겹침 검사도 그대로 적용한다. 별도 확률/Event Director는 없다. 먼저 재고를 진열해야 실제 쇼핑·사고가 발생한다. 재고가 없거나 Pickup 전에 상품을 빼앗으면 기존 품절 퇴장이므로 Spill도 생기지 않을 수 있다.
- `CustomerManager.spawn_customer()`에 선택적 PackedScene 인자만 추가했다. 일반 생성 경로의 예약/가격/금전 처리는 바꾸지 않았다. 사고 이후 Checkout 검사는 실제 Scan/Pay 입력으로 확인한다.
- `SpillZone`: 사고 위치 아래 StaticBody 바닥에 ray를 쏘고 위쪽 면을 확인한 뒤 생성한다. 파란 반투명 원판 Mesh와 바닥 접촉용 얇은 Area3D를 사용한다. 고체 충돌체/액체 시뮬레이션은 없고 자동 소멸하지 않는다. 물리 대상은 layer 1, Spill 감지는 layer 16, Mop 감지 mask 16이다.
- `SlipState`: 진입한 Body에 하나만 붙는 공통 상태. Spill weak reference들을 추적하며 가장 강한 효과만 사용한다. 겹친 Spill의 배율을 곱하지 않는다. 하나에서 나와도 다른 영역 안이면 유지하고, 마지막 영역 이탈/청소/삭제 시 원상복구한다.
- RigidBody에는 기존 PhysicsMaterial을 복제해 개별 마찰과 linear_damp만 낮춘다. 공유 리소스를 수정하지 않고 원래 material 참조 및 damping을 복구한다. Carry 중 상품/Character는 modifier를 잠시 끄므로 Hold 조작감을 훼손하지 않는다. 공중에서는 바닥 Area와 겹치지 않는다.

### 대상별 반응

| 대상 | Spill 위 변경 | 유지하는 것 |
| --- | --- | --- |
| Player | 바닥 위 이동 가속/감속 ×0.3; 이전 방향의 관성 증가 | 최고 속도 5m/s, WASD/Jump/Grab/계산 입력 |
| 상품 | 마찰 최대 0.04, 기존 linear_damp ×0.2 | 실제 RigidBody, price/weight, Throw/충돌 |
| Held Cart | 전진 가속 ×0.85, 제동 ×0.3, 조향 ×0.6, 횡방향 속도 보정 감소 | 마른 바닥의 빠른 제어값, 질량·Launch·Cart Bomb·기존 Damage |
| Free Cart | 구름 저항 ×0.3, 바디 마찰/감쇠 감소 | 실제 물리 이동·적재·탑승 |
| Basic Customer / Parent | 젖은 바닥에서 목표 속도까지 가속 14×0.3 | 쇼핑/가족 상태 흐름과 기존 충돌 규칙 |
| Drunk | 방향 흔들림 ×1.8, 보행 가속 ×0.3 | Carry 85%, 카트 탑승, 파손/Removal |
| Lost Child | 바닥 물리 마찰 및 재회 후 Follow 가속 감소 | Carry 98%, 매칭, Throw 차단, Family Exit |

마른 바닥은 기존 이동 분기를 그대로 실행한다. Spill로 전체 gameplay/input을 잠그는 상태는 없다.
젖은 NPC는 보행과 기존 Cart `_push`를 합친 목표 속도를 한 번 추종한다. 이전 속도에 `_push`를 매 프레임 다시 더해 폭주하지 않도록 했고 반복 밀침의 실제 속도 상한을 검사한다.

### Mop / 청소 / Hold

- Mop은 `GrabbableBody`를 상속한 실제 2kg RigidBody다. 손잡이와 머리에 각각 Box Collision이 있고 머리에 CleaningHead Area가 있다. Mart Backroom 오른쪽 `(7.5, 0.85, -1.5)`에 한 개 배치한다.
- 기존 좌클릭 Grab/Drop, 우클릭 Charge Throw를 그대로 사용한다. `product_type`은 비어 있고 price=0이라 판매 상품이 아니며, Mop 전용 scripted combat damage도 없다. 고체 머리/손잡이는 상품·NPC·카트를 물리적으로 밀 수 있다. 자동 귀환하지 않는다.
- CleaningHead의 **실제 수평 위치 변화 / physics delta**로 속도를 구한다(회전으로 움직인 머리도 포함). 들고 있음 + Spill과 실제 Area 겹침 + 최소 속도 이상일 때만 `clean_rate × delta`를 더한다. 정지/공중/내려놓은 도구는 자동 청소하지 않는다. 순간이동 같은 지나친 속도는 제외한다.
- 진행에 따라 원판과 실제 감지 반경을 함께 줄인다. 완전히 닦으면 `cleaned` 신호를 한 번 보내고 삭제한다. UI 청소 모드/E 원클릭 삭제/별도 Inventory는 없다.
- 긴 Mop에도 Prompt 6.2 Safe Hold를 적용하기 위해 PlayerInteraction의 현재 바디→후보 목표 Sweep을 모든 직접 자식 CollisionShape3D(머리+손잡이)에 적용했다. 기존 단일 Shape 상품/캐릭터는 동일하게 동작한다. Transform 순간이동/World Collision 제거 없이 기존 거리 보정, Grace, Safety Drop을 유지한다.
- 실제 조작은 바닥을 내려다봐 머리를 닿게 하고, 줄어드는 물웅덩이 중앙을 따라 좌우로 문지른다. 걸어가 버리면 머리가 영역을 벗어나 청소가 멈춘다.

### Inspector 기본값 / 통계

| 스크립트 | 변수 | 기본값 |
| --- | --- | ---: |
| AccidentManager | enable_accident_test_spawn / max_accident_customers | true / 2 |
| AccidentManager | spill_radius | 1.5m |
| AccidentCustomer | embarrassment_time | 0.8초 |
| SpillZone | radius / control_multiplier | 1.5m / 0.3 |
| SpillZone | wet_friction / damping_multiplier | 0.04 / 0.2 |
| Mop | weight / carry_radius | 2kg / 0.86m |
| Mop | clean_rate | 0.6/초 |
| Mop | minimum_clean_speed / maximum_clean_speed | 0.3 / 8m/s |
| ShoppingCart | wet_drive_multiplier / wet_steering_multiplier | 0.85 / 0.6 |
| DrunkCustomer | wet_wobble_multiplier | 1.8 |

`AccidentManager.spills_created`는 바닥 Spill 생성 성공 시, `spills_cleaned`는 완전 청소 신호 시 +1. 화면 오른쪽 상단 O 안내 옆에 표시한다. 씬 재시작 시 초기화하며 저장/정산/Spill 자체 금전 손실은 없다. 런타임 생성 노드 설정은 해당 스크립트 기본값 또는 Remote Inspector에서 확인할 수 있다.

### 생성 / 변경 파일

- 새 스크립트: `scripts/interaction/slip_state.gd`, `mop.gd`; `scripts/systems/accident_customer.gd`, `accident_manager.gd`, `spill_zone.gd`.
- 새 씬: `scenes/interactables/accident_customer.tscn`, `spill_zone.tscn`, `mop.tscn`.
- 기존 수정: `player_controller.gd`, `basic_customer.gd`, `drunk_customer.gd`, `lost_child.gd`, `shopping_cart.gd`의 wet 이동 분기; `player_interaction.gd`의 복합 Shape Sweep; `customer_manager.gd`의 생성 씬 선택; `mart_graybox.gd`의 배치; `project.godot`의 O action.
- 검사: `tests/prompt7_smoke.gd` 추가. 기존 Prompt 0~6.2 검사는 최종적으로 변경하지 않았다(3.1 fixture 진단 변경은 원복, 아래 근거). Godot 생성 `.gd.uid`도 함께 보존한다. 조작 안내는 README에 추가했다.

### 검사 이력 / 현재 검증

- 초기 `.godot/p7_first.log`: 동적 Node 호출 결과의 `second` 타입 추론 오류. 명시적 타입으로 수정했다.
- `.godot/p7_second.log`: 동적 Node를 통해 Array[StringName]/Array[RID] 인자를 보낼 때 타입 변환 실패. AccidentManager class_name 및 타입 지정, 명시적 RID 배열로 실제 코드와 검사를 수정했다. 중단 로그를 보존했다.
- `.godot/p7_third.log`: 좌우 보행 검사에서 관성으로 물웅덩이를 벗어나 청소 완료 실패. 청소 조건을 약화하지 않고 축소 영역 중심에서 카메라 yaw로 실제 Mop 머리를 움직이는 동작으로 검사를 수정했다.
- `.godot/p7_fourth.log`: 실제 문지르기 청소 1.65초 통과. 자유롭게 선 Mop이 먼저 넘어져 상품을 빗나가는 충돌 fixture가 실패했다. 해당 검사에서만 회전을 잠그고 실제 머리 접촉을 재현하도록 초기 간격을 좁혔다. gameplay Mop 회전은 그대로 자유다.
- 실제 렌더 캡처에서 새 Spill 통계와 기존 취객 HUD가 겹친 것을 확인해 신규 통계만 오른쪽 상단에 배치했다.
- 첫 회귀 `.godot/final7_prompt3_1.log`: 적재 카트 1초 정지 속도 0.66m/s로 <0.5 기준 실패. 다른 가속/회전/Grab은 통과했다. 진단 `.godot/p7_cart_probe.log`에서 Player/Cart wet=false, 기존 제동 21.43 유지, 제어 입력 0을 확인했다. 별도 진단 실행에서는 0.43으로 통과했지만 정지 중 사용하지 않는 **ObjectD**와 충돌하여 속도가 다시 증가하는 간섭을 기록했다. 첫 실패 순간의 접촉 로그는 없어 그 원인을 동일하다고 단정하지 않는다. 제어 검사만 unused 상품을 경로 밖에 freeze하고 실제 16kg 동적 적재물 B/E·기존 모든 기준은 유지했다. gameplay Cart 제동을 변경하거나 성공할 때까지 반복하지 않았다.
- fixture 분리 후 `.godot/final7_verified_prompt3_1.log`에서도 0.74로 실패하여 단일 원인으로 확정하지 않았다. **마지막 커밋을 `.godot/p7_baseline`에 별도 추출한 수정 전 프로젝트** 역시 동일한 검사에서 0.67로 실패했다(`.godot/p7_baseline_cart.log`). 기존 문서에 기록된 3.1 물리 검사 산포가 재현된 것으로, 원인을 고쳤다고 주장하지 않는다. 불필요한 fixture 변경을 원복하고 기존 검사 계약과 마른 카트 코드는 유지했다. 원본 프로젝트/Git 이력은 건드리지 않았다.
- 비교 조건을 `--fixed-fps 60`으로 통제하자 **수정 전/현재 프로젝트 모두 동일하게 통과**했다(`p7_baseline_fixed_cart.log`, `final7_fixed_prompt3_1.log`). 빈/적재 카트 1초 후 속도는 두 프로젝트에서 각각 정확히 약 0.112/0.103m/s였다. 가속/회전 측정도 동일했다. 기존 3.1 검사는 render/physics 대기 타이밍에 민감하므로 이 검사 재현 시 고정 간격 옵션을 사용한다. 일반 실행의 물리 산포 원인을 완전히 제거한 것은 아니며 기존 검사를 완화하지 않았다.

### 최종 자동 검사 결과

**Prompt 0~7 총 598개 통과(기존 543 + 신규 55), 최종 검사 로그 오류 0건.** 아래 최종 결과와 위 초기 실패 이력을 구분한다. Prompt 3.1 최종 결과는 실제 창의 `--fixed-fps 60` 실행이며 나머지 입력 검사는 기존 실제 창 순차 실행이다. 자동 검사로 사람의 조작감 평가를 대신하지 않는다.

| Prompt | 통과 |
| --- | ---: |
| 0 | 22 |
| 1 / 1.1 | 48 / 40 |
| 2 / 2.1 | 41 / 28 |
| 3 / 3.1 | 32 / 29 |
| 4 | 54 |
| 5 / 5.1 / 5.2 | 33 / 36 / 57 |
| 6 / 6.1 / 6.2 | 40 / 35 / 48 |
| 7 | 55 |

- 최종 로그: `.godot/final7_prompt{0,1,1_1,2,2_1,3}.log`, `.godot/final7_fixed_prompt3_1.log`, `.godot/final7_verified_prompt{4,5,5_1,5_2,6,6_1,6_2,7}.log`. NPC 속도 누적 방지 이후 Prompt 4 추가 검사는 `.godot/final7_npc_prompt4.log`다. 로그는 로컬 Godot 작업 자료이며 Git에 넣지 않는다.
- 임포트 `final7_import.log` 및 최종 코드 재임포트 `final7_import_verified.log` 모두 종료 0. Main `final7_main.log`: `--headless --path . --fixed-fps 60 --quit-after 7200`로 120초 시뮬레이션 종료 0, 배송 도착/출발 및 SCRIPT ERROR/ERROR:/FAIL: 0건. NPC 수정 후 추가 Prompt 4도 54개 통과했다.
- 신규 검사는 사고 손님의 실제 두 종류 Shelf 방문/물리 Pickup/Scan/Pay($55)/퇴장, O 입력/2명 제한, 겹친 Spill과 원본 material 복구, Player 조향/정지, 1kg 상품 마찰, 카트/취객/부모 반응, NPC 밀침 속도 누적 방지, 실제 Mop Grab/급회전/바닥 접촉/정지/문지르기/축소/청소 통계/Drop/물리 밀기/Charge Throw를 검사했다.
- 실측(테스트 조건, 보장 거리 아님): Player 5m/s에서 0.5초 제동 이동량 마른 0.48m / 젖은 1.57m; 1kg Can 회전 잠금으로 sliding만 분리하고 같은 2.8Ns impulse 후 0.75초 이동량 0.45m / 1.83m. 실제 Hold로 바닥에 닿은 Mop을 좌우로 움직여 약 1.65초에 청소 완료했다.
- `.godot/p7_mop.png` 실제 렌더 캡처를 확인했다. 파란 Spill 경계/흰 Mop 머리/오른쪽 상단 통계가 보이며 신규 HUD 겹침은 해소됐다. 사람의 수동 조작감 테스트를 수행했다고 주장하지 않는다.
- 최종 `git diff --check` 통과. tracked 수정 11개 / 새 파일 15개(UID 6개 포함), 전부 uncommitted. 기존 Prompt 0~6.2 테스트 파일의 최종 diff는 없다.

재실행 예(프로젝트 루트 PowerShell, 기존 ZIP 경로 유지):

```powershell
& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --headless --path . --editor --import --quit
& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --path . --script res://tests/prompt7_smoke.gd
& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --path . --fixed-fps 60 --script res://tests/prompt3_1_smoke.gd
```

전체 회귀는 위 표의 `tests/prompt*_smoke.gd`를 창 하나씩 순차 실행한다. headless는 입력 검사의 대체가 아니다. 이전 테스트를 삭제하거나 실패 로그를 덮어 통과로 만들지 않는다.

### 수동 확인 / Known Issues / 다음 작업

1. F5 → 배송 상품 진열 → O. 첫 Shelf Pickup 뒤 Spill·당황 표정, 이어지는 쇼핑/Scan/Pay를 확인한다.
2. 마른/젖은 바닥에서 직진 후 놓기, 좌우 전환을 비교한다. 상품을 발로 차고 빈/적재 Cart의 제동·조향도 비교한다.
3. K 취객을 Spill로 유도하여 흔들림을 비교한다. L 미아 Carry/매칭과 가족 퇴장도 병행한다.
4. 뒤편 Mop을 잡아 물웅덩이를 내려다본다. 정지/공중에서는 그대로, 실제 좌우 문지르기에서 축소·삭제·CLEANED 증가를 확인한다. 머리가 작은 잔여 영역을 벗어나면 다시 중앙으로 가져간다.
5. Mop Drop/Charge Throw, 상품 밀기, NPC/Cart 접촉, 벽 옆 빠른 시점 회전을 확인한다. 일반 계산·입고는 계속 가능해야 한다.

- **Cart Contact Repeated Damage 유지:** 카트를 대상에 밀착해 비비면 반복 피해가 발생할 수 있다. 이번 작업에서 변경하지 않았다.
- 미끄러움/젖은 카트 조작감은 수동 조율 대상이다. 큰 장애물에 끼임, 기존 NPC 경로 정체, 물리 적재 이탈은 여전히 가능하다. 군중 회피/유체 합치기를 추가하지 않았다.
- Spill은 감지 영역 방식으로, 복잡한 요철/완전히 겹친 물체의 실제 접촉면까지 해석하지 않는다. 현 Graybox 평면 바닥을 대상으로 한다. 영역에 부분적으로 닿은 바디는 전체 마찰이 바뀐다.
- Mop은 자동 자세 정렬/IK 없이 기존 Hold를 쓴다. 바닥을 내려다봐야 머리가 닿으며, 작은 잔여 Spill을 계속 지나치면 청소가 오래 걸린다. 실제 조작감 수동 확인은 필요하다.
- 다음 단계 Dangerous Customer / Fire / Fire Extinguisher는 기존 Customer 생성 경로와 공통 물리 도구 기반을 재사용할 준비만 되어 있다. 해당 콘텐츠/시스템은 아직 구현하지 않았다.

## Prompt 6.2 — Held Object / Character Rapid Turn Stability Fix (구현·자동 검증 완료)

이 절은 이전 단계의 즉시 자동 Drop 규칙을 대체한다. Prompt 6/6.1의 기존 uncommitted 작업(tracked 7개/untracked 12개)을 보존했고 새 콘텐츠는 추가하지 않았다. 아래 최종 검증 상태를 확인하고 이 작업을 다시 구현하지 않는다.

### 실제 원인과 재현

- `player_interaction.gd._update_hold_target()`에는 이미 카메라 원점에서 carry_radius Sphere Sweep이 있었다. 그러나 카메라 위치의 검사 구가 어떤 물리 물체와 겹치면 즉시 `drop_held()`했다. 플레이어 캡슐이 설 수 있는 벽 옆에서도 상품 0.49m/취객 0.82m/미아 0.55m 검사 구는 벽과 겹칠 수 있다.
- 별도로 `_physics_process()`는 카메라–바디 거리 >4m이면 한 프레임 만에 해제했다. 순수 제자리 yaw만으로 이 거리가 반드시 커지는 것은 아니다. 이동·충돌·물리 지연과 함께 발생하면 복구 기회가 없다는 문제다.
- 기존 카메라 목표는 1.7m 앞이었다. 한 tick 180도 회전 시 목표가 최대 3.4m 이동하지만 바디는 상품 8m/s, Character 7m/s 및 가속 상한으로 추종한다. 카메라→목표만 검사하고 바디의 현재 위치→새 목표 사이 모서리 경로는 검사하지 않았다.
- 수정 전 `.godot/p62_baseline.log`: 상품/취객/미아 모두 벽 옆 90/180도 회전에서 Hold 상실(실패 3개). 해제 후 카메라와 거리는 약 1.81m로, 이 재현의 직접 원인은 거리 4m 초과가 아니라 카메라 구의 초기 겹침이었다. 두 바디 스크립트에는 별도 자동 Drop 조건이 없고 공통 PlayerInteraction이 해제를 결정한다.

### 공통 Safe Hold / 거리 복귀

- 실제 수정은 `PlayerInteraction`에 집중했다. `GrabbableBody`, `CarryableCharacter`, Drunk/LostChild 및 Family Exit 로직은 이번 단계에서 변경하지 않았다.
- 기본 경로: 카메라→원래 Hold 지점에 기존 보수적 Sphere Sweep + margin을 적용해 가능한 거리를 구한다. 카메라 검사 구의 초기 겹침은 더 이상 해제하지 않는다. 이때는 전방 ray로 중심이 장애물 뒤로 가지 않게 범위를 제한하고, 아래 실제 바디 Sweep을 사용한다.
- 원하는 거리는 장애물에서 즉시 축소하고, 공간이 열리면 초당 6m로 원래 거리까지 복귀한다. 목표 좌표는 초당 12m의 이동 상한을 둔다. 카메라 입력에는 제한/지연을 추가하지 않는다.
- 이어서 대상의 **실제 CollisionShape3D(상품 Box / 캐릭터 Capsule)** 현재 월드 Transform에서 후보 목표까지 Shape Sweep한다. 급회전 시 진열대 모서리를 가로지르는 경로도 여기서 제한한다. 최종 좌표를 기존 `hold_target`에 전달하며 기존 물리 속도·가속/CCD/월드 충돌은 유지한다. 바디 위치를 snap하거나 freeze하지 않는다.
- 디버그용 공개 상태는 `desired_hold_position`, `safe_hold_position`, `hold_obstructed`, `break_timer`다. 게임 화면에 새 Debug UI는 없다. 현재 공통 씬의 단일 `CollisionShape3D`를 사용하며 복잡한 복합 Collider 지원은 추가하지 않았다.

### Safety Drop / Inspector 기본값

| 변수 | 기본값 | 의미 |
| --- | ---: | --- |
| hold_distance | 1.7m | 기존 기본 운반 거리 |
| hold_strength | 12 | 상품 추종 계수, 기존 유지 |
| max_carry_speed / max_carry_acceleration | 8 / 45 | 상품 물리 상한, 기존 유지 |
| break_distance | 4m | 경고/복구 거리, 즉시 해제하지 않음 |
| hard_break_distance | 6m | 심한 이격 판정 |
| break_grace_time | 0.5초 | 심한 이격 해제 유예 |
| stalled_release_time | 3초 | 복구 진행이 없는 정체의 해제 시간 |
| hold_obstruction_margin | 0.03m | Hold 경로 충돌 여유 |
| hold_target_speed | 12m/s | 목표 좌표 이동 상한 |
| hold_distance_return_speed | 6m/s | 장애물 해소 후 거리 복귀 속도 |

- >6m에서 유예 시간을 누적하고 <4m로 회복하면 0으로 초기화한다. 4~6m 구간은 누적을 멈추고 기존 타이머를 보존하는 hysteresis다. 0.5초 도달 시 Safety Drop한다. 심한 이격 중 Charge를 취소하여 유예 중 멀리 있는 상품을 원격 발사하지 않는다.
- 4m 밖, 또는 장애물에 막혀 카메라와 `hold_distance + carry_radius`보다 멀고 원래 목표와 1m 이상 떨어진 상태에서, 실제 이동량으로 측정한 속도가 0.25m/s 미만인 상태가 3초 이어지면 해제한다. 단순 정상 벽 접촉만으로 정체 타이머를 올리지 않는다. 속도 속성은 접촉/고정 시 남을 수 있으므로 실제 위치 변화량을 쓴다.
- 직접 좌클릭 Drop은 즉시, 상품 Charge Throw는 기존 방식, Character Throw는 계속 차단한다. 소유권 상실/바디 삭제 시 Hold·Charge·타이머를 정리한다. Player 충돌 예외를 유지하며 Shelf/Wall 충돌은 제거하지 않는다. Cart는 기존 제어·emergency break 경로를 그대로 사용한다.
- 취객 85%, 미아 98% 이동 배율과 Drop 인계/Family Exit/Drunk Removal은 그대로다.

### 파일 / 검사 이력

- 수정: `scripts/interaction/player_interaction.gd`, `tests/prompt1_1_smoke.gd`, `tests/prompt5_smoke.gd`, 이 문서. 신규: `tests/prompt6_2_smoke.gd` 및 UID. README/Agent/Skill은 새 입력이나 일반 원칙 변화가 없어 이번 단계에서 수정하지 않았다.
- 기존 Prompt 1.1의 “멀리 이격된 상태의 대기 중 Throw보다 Safety Drop 우선” 검사는 그대로 유지한다. 새 유예 정책에 맞게 바디를 원격 위치에 고정하고 `break_grace_time` 이후 동일한 held=null/charge=0/damage=0을 검사한다. 즉시 해제를 요구하던 2 tick 대기를 변경했고 검사 삭제/피해 기준 완화는 하지 않았다.
- `.godot/p62_first.log`: GDScript가 동적 바디 속성으로 만든 `stuck` 타입을 추론하지 못해 파싱 실패. 명시적 bool로 수정하고 오류 실행을 종료했다. `.godot/p62_second.log`: 최초 재현 전부 통과.
- `.godot/p62_extended.log`: 보강 검사 중 장시간 고정 바디 정체 해제 1건 실패. freeze된 테스트 바디가 기존 linear_velocity를 남겼고 속도 속성만으로는 정체를 확인하지 못했다. 게임 코드의 정체 감지를 실제 위치 변화량으로 변경했다. 실패 로그는 보존한다.
- 첫 전체 회귀 Prompt 5에서 Carry/벽/Drop/직접 제거/카트 제거/계산은 통과했으나 진열대 충돌 테스트의 “안정된 상품 준비” 1건이 실패했다(`.godot/p62_regression_first_prompt5.log`). 이 구간은 풀어놓은 취객의 랜덤 배회 중 상품을 진열하고 있었다. 당시 접촉/위치를 기록하지 않았으므로 원인을 단정하지 않는다. 별도 `.godot/p62_stock_probe.log`에서는 취객이 가까울 때 준비 상품이 (-5,1,5.5)에서 (-5.23,0.80,5.93)으로 이동하고, 멀 때는 (-5.00,0.80,5.50)에 유지되는 간섭을 확인했다. 두 진단(`p62_stock_late_contact.log` 포함)에서는 Stock 검사가 최종 통과해 최초 실패 자체가 동일하게 재현된 것은 아니다.
- 초기 조건을 분리하기 위해 **Prompt 5의 이 준비 구간에서만** 취객을 (7,0.8,2)에 두었다. AI는 끄지 않고 진열 준비 뒤 기존 (-5,0.76,3.9) 위치에서 실제 Shelf 충돌을 그대로 시작한다. 앞선 배회/Drop 후 AI 재개와 뒤의 상품 흔들림·파손·Carry/Cart 제거·계산 검사는 모두 유지한다. Shelf 판정 기준/대기 시간/게임 취객 코드는 수정하지 않았다. 이 fixture 수정 후 해당 단계와 아직 실행하지 않은 회귀를 이어서 실행한다.
- 최종 전체 결과는 `.godot/final62_*.log`에 기록했다. 신규 48개 검사는 상품/큰 Appliance/취객/미아의 급회전, 실제 Shelf/Wall, 정상 위치 복귀, 이동 중 회전, 월드/Player 충돌 규칙, 수동 Drop, Character Throw 차단, 일시적/지속 이격, 장기 정체, 노드 삭제를 포함한다.

### 최종 자동 검사 — 2026-09-29

**총 543개 통과, 최종 실패 0개**(기존 495 + 신규 48). 각 단계 완료 문구와 종료 코드 0을 확인했으며 최종 import/회귀/Main 로그의 SCRIPT ERROR/ERROR:/FAIL:는 0건이다. 최초 실패 로그는 위 별도 파일로 보존했다.

| Prompt | 통과 | 실패 |
| --- | ---: | ---: |
| 0 | 22 | 0 |
| 1 | 48 | 0 |
| 1.1 | 40 | 0 |
| 2 | 41 | 0 |
| 2.1 | 28 | 0 |
| 3 | 32 | 0 |
| 3.1 | 29 | 0 |
| 4 | 54 | 0 |
| 5 | 33 | 0 |
| 5.1 | 36 | 0 |
| 5.2 | 57 | 0 |
| 6 | 40 | 0 |
| 6.1 | 35 | 0 |
| 6.2 | 48 | 0 |

- 실제 물리 검사에서 작은 상품/Appliance/취객/미아 모두 벽 옆 급회전 후 held=true였다. 장애물 제거 후 정상 Hold 목표 0.25m 이내 복귀, 실제 Shelf 반대편으로 관통하지 않음, 이동하면서 90/180도 회전 유지, 좌클릭 Drop 및 Character 투척 차단을 확인했다. 6.5m 단기 이격은 유지/복귀하고 0.5초 지속 시 해제, 4.5m 장기 정체는 3초 후 해제됐다.
- 기존 상품 가격/무게/피해/넉백, Cart Bomb, 배송/진열/계산, 취객 운반·카트 제거, 미아 인계·카트 운반, 6.1 가족 교차/퇴장 검사를 모두 통과했다. 사람이 직접 장시간 플레이한 수동 확인으로 해석하지 않는다.
- Godot 4.7.2 임포트 성공. Main은 headless fixed-fps=60, 7,200프레임(시뮬레이션 120초)으로 실행했고 배송 6개 도착/출발까지 확인했다. 신규/회귀 smoke는 창 모드에서 하나씩 순차 실행했다.
- `git diff --check` 오류 없음. 이전 Prompt 변경 포함 tracked 수정 9개/untracked 14개이며 전부 uncommitted다. Git의 사용자 전역 ignore 권한 경고/CRLF 안내는 남지만 status/diff 종료 코드는 0이다. commit/amend/reset/push를 실행하지 않았다.
- 재실행은 기존 실행 파일 `D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`에 `--path . --script res://tests/prompt6_2_smoke.gd`를 사용한다. 전체 검사 목록은 `0, 1, 1_1, 2, 2_1, 3, 3_1, 4, 5, 5_1, 5_2, 6, 6_1, 6_2`다. import/Main headless와 창 모드 회귀 절차는 아래 기존 실행 예시를 따른다.

### 수동 확인 / Known Issues / 다음 작업

1. 작은 상품과 Appliance를 각각 Grab하고 중앙에서 빠르게 좌우 90/180도 회전한다.
2. Shelf/Wall 옆에서 회전·이동한다. 잠깐 닿아도 유지되고 관통하지 않으며 공간을 확보하면 정상 위치로 복귀하는지 확인한다.
3. K 취객 Carry로 반복한다. 85% 이동·우클릭 투척 차단·카트 운반/출구 제거를 확인한다.
4. L 미아 Carry로 반복한다. 98% 이동·투척 차단·올바른 부모 Drop·6.1 가족 퇴장을 확인한다.
5. 테스트 환경에서 대상을 6m 이상 고정하여 0.5초 후 Safety Drop, 잠깐 초과 후 복귀는 유지되는지 확인한다.

- 아주 좁은 공간이나 양쪽이 막힌 모서리에서 물리 접촉/지연은 남을 수 있다. 장애물 우회 경로 탐색이나 완전한 관절 시스템은 없으며 복구 불가능한 지속 정체는 의도적으로 해제한다. 자동 검사로 장시간 수동 조작감을 확정하지 않는다.
- **Cart Contact Repeated Damage는 계속 유지**한다. 이전 Family Exit의 물리 장애물 봉쇄 제한도 유지한다.
- 수동 확인 후 요청 시 Prompt 7 Accident Customer / Spill / Slippery Floor로 이어갈 수 있다. 이번 작업에서는 새 콘텐츠를 구현하지 않았다. 모든 변경은 uncommitted로 두며 commit/amend/reset/push하지 않는다.

## Prompt 6.1 — Lost Family Exit / NPC Deadlock Fix (구현·자동 검증 완료)

현재 구현은 아래 Prompt 6의 퇴장 설명을 대체한다. 새 콘텐츠는 추가하지 않았다. 시작 시 Prompt 6의 tracked 수정 7개와 신규 10개가 이미 uncommitted였으며 그대로 보존했다.

### 원인과 수정 구조

- 기존 Child는 부모 중심을 목표로 하고 거리 0.9m 안에서 멈췄다. 실제 뒤/옆 위치가 아니었고 Parent/Child 직접 충돌도 유지되어 정면 Drop 시 서로 막혔다. 퇴장 가족과 새 Basic Customer의 직접 충돌 역시 계속 활성화되어 반대 방향 이동이 정체되었다.
- `LostChild.follow_position()`은 Parent의 현재 퇴장 waypoint 방향 기준 **뒤 0.9m + 오른쪽 0.35m**다. Inspector 변수 `follow_distance=0.9`, `lateral_offset=0.35`, `walk_speed=2.3`, `follow_correction=3`, `follow_acceleration=16`, `recovery_start_distance=2`, `recovery_speed=4.5`를 사용한다. 간격 증가 시 최대 속도를 점진적으로 높이고 매 물리 구간 수평 속도만 보정한다. 매 프레임 Transform 복사/순간이동/바디 부착은 없다. 재회 후에는 카트 지지 상태도 바닥 접촉 추종을 허용한다. 재회 전 Carry/카트 동작은 기존 그대로다.
- `LostParent`는 퇴장 waypoint의 수평 방향을 `exit_direction`으로 제공하고 해당 방향을 바라본다. 기존 BasicCustomer 이동을 그대로 호출한다. `uses_customer_separation()` 기본값 true, 재회 Parent만 false로 재정의하여 일반 손님 거리 벌리기 보정이 부모를 다시 밀어 멈추지 않게 한다. 일반 손님끼리의 쇼핑/Queue/충돌 규칙은 바꾸지 않았다.
- `LostFamilies.try_reunion()`은 기존 Drop ownership 해제 이후 ID/거리/차폐 검증을 통과하면 reunited/수면 해제, 상호 충돌 예외, 성공 카운트와 하트 대기 상태를 설정한다. 0.8초 후 Parent EXIT, Child는 물리 추종한다. reunited 가드가 중복 성공을 방지하고 재Grab은 계속 차단한다.
- 충돌 예외는 **양쪽 바디**에 적용한다: 재회한 자기 가족 Parent↔Child, 재회한 가족↔기존 Basic Customer, 재회한 가족↔다른 재회한 가족. SceneTree `node_added`에서 재회 후 들어오는 새 Basic Customer에도 첫 이동 전에 적용한다. 미해결 다른 가족 및 일반 Customer↔Customer는 그대로다. Drunk, Player, Cart, 상품, 벽/진열대/지형에 대한 충돌 Layer/Mask는 바꾸지 않는다.
- `_npc_exceptions`는 이 Manager가 추가한 방향별 예외만 WeakRef로 기록한다. 가족 완료/비정상 한쪽 소멸/Manager 종료 시 생존 바디의 예외를 해제한다. 기존 다른 소유자의 예외는 지우지 않는다.
- **Parent가 정상 출구에 도착하면 두 바디와 이벤트를 함께 정리**한다. Child 자체의 출구 Trigger나 부모와 2m 이내 여부를 더 이상 기다리지 않는다. 아이가 뒤에 남아 출구를 점유하는 문제가 가족 완료를 막지 않는다. 통계는 재회 시에만 증가한다.

### 변경 파일과 검사 이력

- 이번 재개에서 수정: `scripts/systems/lost_child.gd`, `lost_parent.gd`, `lost_family_manager.gd`, `basic_customer.gd`, `PROJECT_NOTES.md`, `README.md`. 신규: `tests/prompt6_1_smoke.gd`와 UID. 기존 Prompt 0~6 검사, 공통 Carry, Drunk, Cart, 판매/예약은 수정하지 않았다. Agent/Skill도 변경하지 않았다.
- 수정 전 `.godot/p61_baseline.log`: 실제 재회 성공 후에도 상호 충돌 예외 없음/offset 추종 API 없음 두 검사가 실패했다. `.godot/p61_first.log`: 신규 Child 코드 들여쓰기 오류로 파싱 실패, 즉시 수정했다. `.godot/p61_second.log`: 신규 검사가 실패 0으로 완료됐다. 실패 로그를 보존한다.
- 보강한 벽 검사에서 벽을 치운 뒤 퇴장/예외 정리 2건이 실패했다(`.godot/p61_wall_fixture_failure.log`). 진단 실행 `.godot/p61_wall_diagnostic.log`에서 부모 위치 (6,0.000292,9.254052), 속도 0, 실제 접촉 바디 `/root/Main/MartGraybox/Customers/Checkout/Counter`를 확인했다. 검사 전용 직선이 기존 계산대(x=5,z=10)를 가로지른 배치 오류였다. 해당 신규 fixture만 x=7.5의 빈 동선으로 옮겼다. “벽에는 막힘 → 벽 제거 후 퇴장 → 임시 예외 정리” 계약은 유지하고 게임의 계산대/충돌/경로 코드는 변경하지 않았다. 기존 회귀 파일도 변경하지 않았다.
- 최종 전체 회귀/임포트/Main 결과는 `.godot/final61_*.log`에 보존했다. 기존 회귀 460개 + 신규 35개 = **495개 통과, 최종 실패 0개**. 아래는 2026-09-29 실제 실행 결과다.

| Prompt | 통과 | 실패 |
| --- | ---: | ---: |
| 0 | 22 | 0 |
| 1 | 48 | 0 |
| 1.1 | 40 | 0 |
| 2 | 41 | 0 |
| 2.1 | 28 | 0 |
| 3 | 32 | 0 |
| 3.1 | 29 | 0 |
| 4 | 54 | 0 |
| 5 | 33 | 0 |
| 5.1 | 36 | 0 |
| 5.2 | 57 | 0 |
| 6 | 40 | 0 |
| 6.1 | 35 | 0 |

- Godot 4.7.2 임포트 성공. Main headless fixed-fps=60/7,200프레임(120초 시뮬레이션), 배송 도착·출발 확인, 종료 코드 0. 모든 최종 로그에 SCRIPT ERROR/ERROR:/FAIL: 0건. 입력 smoke는 창 모드 순차 실행했다.
- 신규 검사는 정면/몸 겹침 Drop, 실제 부모·아이 이동, 뒤/옆 offset, 새 손님과 실제 정면 교차, 기존 손님 예외, 정상 손님끼리 충돌 유지, 미해결 가족 충돌 유지, 두 가족 퇴장, 비순간이동·회복 속도 상한, 실제 벽 정지/장애물 제거 후 재출발, 이벤트/예외 정리를 확인한다. 기존 미아 40개 검사가 잘못된 부모·Carry·카트 운반·통계·Drunk/Checkout/Delivery 병행을 확인한다.
- 이번 Cart Bomb 회귀 실측: 적재 5개 중 4개 이탈, 차체와 개별 상품 모두 타깃 타격. 물리 산포가 있으므로 이탈 개수를 고정 계약으로 만들지 않는다.
- `git diff --check` 오류 없음. 최종 상태는 이전 Prompt 6 변경을 포함해 tracked 수정 7개 + untracked 12개다. 이번 신규 파일은 Prompt 6.1 검사/UID 2개이며 자동 커밋하지 않았다. Git은 사용자 전역 ignore 읽기 권한 경고 및 CRLF 정규화 안내를 출력했으나 status/diff 검사는 종료 코드 0이다.

재실행은 위에 기록한 기존 절대 경로로 import → `tests/prompt6_1_smoke.gd` → 기존 Prompt 0~6 smoke → Main 순서다. 아래 Prompt 6 PowerShell 반복 목록에 `'6_1'`을 추가하면 전체 검사에 포함된다. 게임 코드에 추가 변경 없이 신규 벽 fixture만 교정했으므로 통과한 기존 회귀 460개는 불필요하게 반복하지 않았다.

### 수동 확인과 남은 제한

1. L → 아이를 올바른 부모 정면 진행 경로에 Drop: 하트/found 1회, 부모 출발, 아이가 뒤/옆으로 추종.
2. 부모 몸에 거의 겹치게 Drop: 폭주/서로 막힘 없이 퇴장. 재회 후 재Grab 불가 확인.
3. 입구에서 새 일반 손님과 퇴장 가족이 정면 교차: 일시적 겹침은 허용하지만 영구 정체는 없어야 한다.
4. L로 두 가족을 생성해 비슷한 시점에 인계: 각각 성공/퇴장, 총 found=2. 잘못된 부모에게는 성공하지 않아야 한다.
5. Queue/배송/K 취객/카트 운반을 함께 실행: 가족 퇴장이 업무를 잠그지 않아야 한다. 카트/Player/벽 충돌은 계속 유지된다.

- NPC 예외 통과 중 시각적 겹침은 의도적으로 허용한다. 군중 회피나 새 경로 탐색은 없다. 실제 카트/상품/Player/취객이 출구 전체를 막으면 부모는 여전히 물리적으로 막힐 수 있다. 아이가 벽/상품에 걸리면 bounded recovery만 적용하며, 부모 출구 도착 시 위치와 무관하게 정리된다. 장애물을 순간이동으로 뚫는 복구는 넣지 않았다.
- **Cart Contact Repeated Damage**: 카트를 대상에 밀착해 비빌 때 반복 피해가 발생하는 기존 Known Issue는 그대로 유지한다. 전투 시스템 이후 재평가한다.
- 자동 검사는 사람의 수동 조작감 검증을 대체하지 않는다. 다음은 위 수동 시나리오 확인이며, 그 뒤 사용자 요청 시 Accident Customer / Spill / Slippery Floor를 검토한다. 이번 작업에서 해당 기능은 구현하지 않았다.
- 모든 변경은 uncommitted 유지. commit/amend/reset/push를 실행하지 않는다.

## Prompt 6 — Lost Child + Parent Matching (구현·자동 검증 완료)

- 이번 구현은 미아/부모 쌍만 추가한다. 아래 단계별 “Lost Child 미구현” 문장은 과거 이력이다. 다음 후보는 Accident Customer + 물/음료 미끄러운 바닥이며 아직 구현하지 않았다.
- `LostChild extends CarryableCharacter`: 높이 1m, 반지름 0.24m 캡슐 RigidBody, mass=2kg, carry_radius=0.55m, carrier_speed_multiplier=0.98. 울음/물음표와 Family Symbol을 표시하고 제자리에서 기다린다. 타이머·쇼핑·Queue·피해·사망·ragdoll은 없다. 취객은 기존 mass=6kg/이동 배율 0.85를 유지한다.
- `LostParent extends BasicCustomer`: 기존 캡슐 외형, 카트 접촉 반응, gravity/move_and_slide, 고정 퇴장 경로를 재사용한다. enum 끝에 EVENT_WAIT를 추가해 기존 상태 번호를 보존했다. Parent는 CustomerManager.customers/queue/예약 목록에 등록하지 않으며 EVENT_WAIT 동안 재고 검증/Patience를 실행하지 않는다. 퇴장 도착 콜백 `finish_exit()`만 가족 이벤트용으로 재정의한다.
- `LostFamilies`는 Mart 초기화 때 추가되는 작은 Node3D Manager다. `enable_lost_child_test_spawn=true`, `max_events=2`(Inspector 1~2), `handoff_distance=1.8m`, `reunion_time=0.8초`. L 개발용 Action `debug_spawn_lost_child`로 생성하며 K 취객 입력과 분리한다. 자동 Event Director는 없다.
- 쌍마다 증가하는 family_id와 정확한 Parent 참조를 사용한다. 활성 슬롯 0은 노란 원(●), 1은 청록 마름모(◆)이며 두 Actor에 동일 색·도형을 표시한다. 빈 슬롯은 재사용하지만 family_id는 재사용하지 않는다. Child 위치 (-6,0.55,2)/(4,0.55,2), Parent 위치 (6,0.01,8)/(-6,0.01,8.3). 두 생성 공간 중 하나라도 막히면 쌍 전체 생성을 건너뛴다.
- 공통 Carry의 새 기본 no-op `on_player_drop()`를 미아가 재정의한다. 좌클릭 토글만 `drop_held(true)`를 호출하고, 끼임/거리/종료 등의 안전 Drop은 기존 기본 false다. 해제할 바디를 지역 변수로 보관하고 held_object를 먼저 비운 뒤 end_carry와 선택적 Drop hook을 실행한다. 상품·카트·취객의 기존 해제/Charge 동작은 유지한다. Character Throw 차단은 기존 CarryableCharacter 타입 판정을 그대로 쓴다.
- 인계는 자발적 Drop 직후 판정한다. family_id와 Parent 참조 일치, 거리 1.8m, 부모 눈높이→아이 사이 벽/진열대 차폐 없음이 필요하다. 운반 중 올바른 부모는 체크를 표시한다. 잘못된 부모/일반 바닥 Drop/강제 안전 해제는 성공하지 않으며 아이도 유지한다. 카트 이동 자체에 전용 인계 트릭은 없다. 카트 운반 후 다시 Carry/Drop하여 인계할 수 있다.
- 성공은 reunited를 먼저 설정해 중복을 막고 `lost_children_found += 1`, 하트를 0.8초 표시한다. 그 뒤 Parent는 기존 출구 경로로 걷고 Child는 바닥 접촉 중 부모를 약 0.9m 뒤에서 물리 속도/가속으로 따라간다(walk_speed=2.3m/s, Parent=1.5m/s). 순간이동/바디 부착/좌석은 없다. 추종 중 sleep을 끈다. Parent가 실제 출구에 도착하고 아이도 2m 안이면 두 바디를 제거하고 이벤트 슬롯을 반환한다. 재회 후 아이의 재Grab은 허용하지 않는다.
- Drunk ExitRemovalZone은 계속 DrunkCustomer만 제거한다. 미아를 밖에 놓아도 found가 증가하거나 삭제되지 않는다. 판매·손실 카운터도 수정하지 않는다. 일반 Checkout/Delivery/Drunk는 이벤트 중 계속 동작한다.
- 신규 씬: `scenes/interactables/lost_child.tscn`, `lost_parent.tscn`. 신규 스크립트: `scripts/systems/lost_child.gd`, `lost_parent.gd`, `lost_family_manager.gd` 및 UID. 신규 `tests/prompt6_smoke.gd`/UID. 수정: project.godot, carryable_character.gd, player_interaction.gd, basic_customer.gd, mart_graybox.gd, README, 이 문서. Agent/Skill과 기존 Prompt 0~5.2 검사 파일은 수정하지 않는다.
- 초기 신규 검사에서 퇴장/카트/계산 병행 실패가 있었다. `.godot/p6_first.log`, `p6_second.log`, `p6_third.log` 보존. 카트와 플레이어가 겹친 fixture를 분리했고, 정지 취객이 출구(-3,11)를 막아 Parent가 z≈10.35에서 정체되는 좌표를 확인했다. 취객은 별도 구역에 두었으며 카트 탑승 검사 후 카트를 Backroom에 주차해 일반 고객 통로도 비웠다. 재회 시 물리 수면 해제와 Parent 대기 위치 경계 여유도 적용했다. 실제 장애물 봉쇄 시 정체는 알려진 제한으로 유지하며 자동 순간이동/통과를 넣지 않았다.
- 수동 확인: L 한 번 → 같은 Symbol 확인 → Carry/일반 Drop → L 두 번의 다른 부모 인계 거부 → 올바른 부모 체크/좌클릭/하트/퇴장 → 카트 탑승·운반 → K 취객/계산/배송 병행. 미아 운반은 취객보다 덜 느려야 한다. 막힌 동선은 직접 비워 본다.
- Known Issues: 카트 밀착 반복 Damage는 의도적으로 그대로다. 기존 고정 waypoint에 장애물이 놓이면 Parent/Customer가 정체될 수 있다. 재회한 아이가 카트 안에 계속 남거나 길이 막히면 퇴장이 지연될 수 있다. 물리 캡슐/도형 라벨은 임시 표현이며 시점에 따라 겹친다. 자동 검사와 사람이 장시간 체감한 수동 테스트는 구분한다.
- Git: 시작 시 작업 트리는 clean이었다. 요청대로 모든 변경을 uncommitted 상태로 남기며 commit/amend/reset/push는 하지 않는다.

### Prompt 6 최종 검사 — 2026-09-29

**총 460개 통과, 실패 0개.** 기존 Prompt 0~5.2의 420개를 수정 없이 유지했고 신규 6의 40개를 추가했다. `.godot/final6_*.log`에 최종 결과가 있으며 모든 최종 검사/임포트/Main 로그의 SCRIPT ERROR/ERROR:/FAIL:는 0건이다.

| Prompt | 통과 | 실패 |
| --- | ---: | ---: |
| 0 | 22 | 0 |
| 1 | 48 | 0 |
| 1.1 | 40 | 0 |
| 2 | 41 | 0 |
| 2.1 | 28 | 0 |
| 3 | 32 | 0 |
| 3.1 | 29 | 0 |
| 4 | 54 | 0 |
| 5 | 33 | 0 |
| 5.1 | 36 | 0 |
| 5.2 | 57 | 0 |
| 6 | 40 | 0 |

- 신규 검사는 L 생성·2쌍 제한·고유 ID/색/도형·쇼핑/Queue 제외·실제 좌클릭 Carry/Drop·이동/벽 안정성·캐릭터 투척 차단·잘못된 부모/벽/강제 Drop 거부·부모 체크·두 번의 인계 성공·중복 차단·실제 퇴장·다른 쌍 유지·취객 제거 구역 예외·실제 카트 운반·일반 매출 $5·배송을 확인했다. found=2이며 카트 위 아이 중심은 약 y=0.907m, 별도 좌석/부착 없이 supported_by_cart=true였다.
- Godot 4.7.2 임포트와 Main fixed-fps 60/7,200프레임(시뮬레이션 120초) 실행에서 배송 도착/출발까지 확인했다. 입력 검사는 실제 창을 하나씩 순차 실행했다. `.godot/p6_reunion.png`를 열어 노란 원/청록 마름모, 작은 아이, 재회 하트와 FOUND 표시를 확인했다. 부모가 Shelf 뒤에서 가려질 수 있는 실제 배치도 확인했으며 장시간 사람이 직접 플레이한 결과로 해석하지 않는다.
- `git diff --check` 오류 없음. 최종 Git은 tracked 수정 7개, 신규 10개(씬 2, 스크립트 3+UID 3, 검사 1+UID 1)이며 모두 uncommitted다. 기존 Agent/Skill 파일과 기존 테스트 파일은 변경하지 않았다.
- 다음 세션은 Prompt 6을 다시 만들지 않는다. 사용자 수동 피드백에서 Carry·인계 거리·기호 가독성·막힌 퇴장 경로 문제를 먼저 확인한다. Accident Customer/물/음료/미끄러운 바닥은 다음 요청 때 설계하며 이번 단계에 선구현하지 않았다.

재실행(프로젝트 루트 PowerShell, 기존 절대 경로 사용):

```powershell
$martGodot = 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
& $martGodot --headless --path . --editor --import --quit 2>&1 | Tee-Object .godot/check6_import.log
foreach ($stage in @('6','0','1','1_1','2','2_1','3','3_1','4','5','5_1','5_2')) {
    & $martGodot --path . --script "res://tests/prompt${stage}_smoke.gd" 2>&1 | Tee-Object ".godot/check6_prompt${stage}.log"
}
& $martGodot --headless --path . --fixed-fps 60 --quit-after 7200 2>&1 | Tee-Object .godot/check6_main.log
```

## Prompt 5.2 — Customer Pickup Feedback + 자동 Godot 검사 (구현·자동 검증 완료)

- 현재 데이터 흐름은 **Shelf 실물 예약 → SHOP에서 실물 제거/논리 Basket 기록 → Checkout에서 Basket 결제**다. 아래 Prompt 5.1까지의 “결제할 때 실물 제거” 기록은 과거 동작이며 이번 변경으로 대체한다. 손님은 여전히 실제 상품을 손에 들거나 몸에 붙이지 않는다.
- `BasicCustomer.goods`에는 아직 Shelf에 남은 예약 물체만 있고, `picked_items: Array[Dictionary]`는 픽업한 개별 수량당 `{product_type, price, source_id}` 한 건이다. price는 해당 물체의 픽업 당시 가격이며 별도 가격표/인벤토리 시스템은 없다. source_id는 예약 원본 식별용 값이며 살아 있는 Node 참조가 아니다.
- SHOP 완료 시 `CustomerManager.pickup_from_shelf()`가 모든 예약의 현재 재고/소유를 재검증하고 해당 종류의 정확한 수량을 원자적으로 이동한다. 한 개라도 없으면 이번 종류는 하나도 제거하지 않는다. 다른 손님의 상품이나 새 재고를 검색해 대신 지우지 않는다. 중복 픽업 요청은 아무 효과가 없다.
- 정상 픽업은 예약 ID 해제 → Basket 기록 → goods 참조 제거 → 실물 숨김/queue_free 순서다. 기존 Shelf 제외 메타 `sold`를 내부적으로 재사용하지만 이 시점에는 sales를 올리지 않는다. `StockShelf.refresh_stock(0)`로 기존 재고 판정/라벨을 즉시 재계산하며 별도 수량을 수동 차감하지 않는다.
- `valid_goods()`는 남은 실제 예약과 Basket의 상품 종류·수량을 함께 확인한다. `finish()`는 전량 픽업·Scan 완료 후 Basket 가격만 sales에 한 번 더하고 비운다. 이미 제거된 상품을 재삭제하지 않는다. 표시 purchase_total도 픽업 가격 스냅샷에 맞춘다.
- Patience 탈출은 이미 챙긴 Basket 가격만 unpaid_loss에 더하고 비운다. 상품은 복원하지 않는다. 전혀 챙기기 전 품절은 손실 0. 여러 종류 중 앞 Shelf에서 챙긴 뒤 뒤 Shelf가 품절되는 경우도 이미 챙긴 부분만 손실 처리한다. resolved와 Basket clear로 중복 집계를 막는다.
- 상품 아이콘별 초록 `✓`는 해당 종류 픽업 시 표시된다. 수량별 기존 아이콘을 그대로 사용하며 텍스트 대사/3D 소지품/효과 Manager는 없다. 체크가 표정과 겹치지 않도록 표정 높이를 2.4m, 체크를 아이콘 위 0.23m로 조정했다. 단순 즉시 제거를 사용하며 별도 Tween은 없다.
- Player Grab/Throw 또는 취객 물리 접촉으로 상품의 정상 재고 조건이 깨지면 같은 품절 경로를 탄다. 구매 예약이 실제 상호작용을 잠그지 않는다. Cart/Drunk/Carry/Delivery 물리 코드는 변경하지 않았다. 카트 밀착 반복 Damage는 계속 Known Issue로 유지한다.
- `AGENTS.md`와 `.agents/skills/godot-testing/SKILL.md`에 사용자 Godot 테스트 사전 허가를 추가했다. 임포트, headless/창 모드 smoke, 회귀, Main, 테스트 씬, 로그 검사를 재확인 질문 없이 자동 실행한다. 정상 검증 범위 밖 작업이나 실행 환경의 명시적 승인 요구만 예외이며 샌드박스 권한/검사 기준을 우회하지 않는다.
- 변경 파일: `basic_customer.gd`, `customer_manager.gd`, `stock_shelf.gd`, Agent/검사 Skill, README, 이 문서. 신규 `tests/prompt5_2_smoke.gd` 및 UID. 기존 Prompt 4의 실물 간섭 검증을 SHOP 직전으로 옮겼고 Prompt 5.1의 실물 유지 검증을 Basket 전환 검증으로 갱신했다. 기존 입력/Queue/금전/품절/분산 검사는 유지한다. Prompt 0~3.1 테스트는 수정하지 않았다. Prompt 5의 마지막 계산 병행 fixture는 아래 이유로 초기 조건만 안정화했다.
- 첫 신규 검사 `.godot/p52_first.log`는 마지막 테스트에서 CharacterBody형 Queue에 RigidBody 취객을 `has()`로 조회해 타입 오류가 났다. 신규 테스트의 조회를 Queue 비어 있음/일반 손님 수 검사로 수정했다. 게임 코드 오류로 숨기거나 실패 로그를 삭제하지 않는다. 수정한 Skill 형식 검증은 통과했다.
- 첫 전체 회귀의 Prompt 5는 Carry 이동 1개와 최종 계산 입력/매출 3개가 실패했다(`.godot/p52_regression_first_prompt5.log`). 초기 실패는 포커스 상태를 기록하지 않아 원인을 단정하지 않는다. 상태만 기록하는 `.godot/p52_focus_probe.gd` 진단 재실행에서는 포커스가 유지됐고 Carry는 통과했지만 계산 고객이 먼저 퇴장해 기존 wait_checkout의 freed 참조 오류와 매출 실패가 발생했다. 랜덤 취객이 정상 예약 재고를 방해할 수 있는 fixture였다. 마지막 계산 병행 구간에서만 취객 `wander_speed=0`, 속도 0으로 두고 실제 취객 존재도 확인하도록 했다. 앞선 실제 배회/상품 충돌/파손/Carry/카트 제거 검사는 그대로이며 신규 5.2에서 취객 접촉→품절을 별도로 검증한다. 게임 취객 로직은 바꾸지 않았고 이 진단 실패 로그도 보존했다.
- 수동 확인: Can×2 픽업에서 정확히 두 실물/Count 감소와 두 체크 → 여러 종류 각각 픽업 → Scan/Pay 때 새로 진열한 상품 보존 → Patience 탈출 손실 → SHOP 직전 Grab/취객 간섭 품절. 정해진 목록은 기존 `Customers.spawn_customer([&"can", &"can", &"watermelon"])`로 재현한다. 별도 새 입력/콘텐츠는 없다.
- 다음 단계: 사용자 수동 확인 뒤 Lost Child 요청 시 기존 Character Carry 재사용을 검토한다. Lost Child/부모/인계 및 다른 특수 손님/라운드/정산/멀티플레이는 아직 구현하지 않았다.

### Prompt 5.2 최종 검사 — 2026-09-29

**총 420개 통과, 최종 실패 0개.** Godot 4.7.2 임포트 성공. Main은 headless, fixed-fps 60, 7,200프레임(시뮬레이션 120초) 동안 배송 도착/출발까지 정상 실행했다. 최종 `.godot/final52_*.log`의 SCRIPT ERROR/ERROR:/FAIL:는 0건이다. 이전 실패 이력은 위 항목과 별도 로그에 보존했다.

| Prompt | 통과 | 실패 |
| --- | ---: | ---: |
| 0 | 22 | 0 |
| 1 | 48 | 0 |
| 1.1 | 40 | 0 |
| 2 | 41 | 0 |
| 2.1 | 28 | 0 |
| 3 | 32 | 0 |
| 3.1 | 29 | 0 |
| 4 | 54 | 0 |
| 5 | 33 | 0 |
| 5.1 | 36 | 0 |
| 5.2 | 57 | 0 |

- 신규 실측: Can×2+Watermelon×1은 두 Shelf에서 순차 픽업 후 $60 결제, 결제 직전 추가한 Can은 살아 있는 Stock 1개로 유지. Can×3 중 실제 물체 하나를 $7로 바꾼 경우 Basket/표시 금액 $17 유지. 미결제 Can 손실 $5, 일부 픽업 후 품절도 실제 챙긴 Can $5만 한 번 기록했다.
- Cart Bomb 회귀는 적재 5개 중 2개 이탈, 차체/개별 상품 각각 타격을 확인했다. 취객 회귀는 직접 Carry 및 카트 발사 제거 총 2회, 취객 존재 중 정상 매출 $5를 확인했다.
- `.godot/p52_pickup.png`를 열어 빈 Can Shelf(0/8), Can 아이콘 위 초록 체크 두 개, 아직 픽업하지 않은 Watermelon 실물(1/5)과 미완료 아이콘을 확인했다. 체크를 키우고 표정을 올린 최종 화면도 확인했다. 장시간 사람 수동 플레이 검증을 대신한다고 해석하지 않는다.
- 수정한 godot-testing Skill은 quick_validate.py 통과, `git diff --check` 오류 없음. `project.godot`의 이전 K키 직렬화 변경은 이번 작업에서 수정하지 않았다. 커밋하지 않았다.
- 남은 제한: 현재 마트 배치에 맞춘 waypoint, 통로 봉쇄 시 정체, 아이콘이 시점/다른 라벨에 따라 겹칠 수 있음, 초기 물리 테스트 산포 및 창 포커스 영향. 카트 밀착 반복 Damage는 요청대로 보존. 새 gameplay 오류가 최종 자동 검사에서 확인되지는 않았지만 사용자 수동 확인은 필요하다.

전체 재실행 시 아래 명령을 사용한다. 테스트 실행 자체에 사용자 확인을 다시 받지 않으며, 실행 환경이 요구하는 권한 절차만 따른다. 테스트 중 다른 창 클릭/Alt+Tab은 입력 fixture에 영향을 줄 수 있다.

```powershell
$martGodot = 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
& $martGodot --headless --path . --editor --import --quit 2>&1 | Tee-Object .godot/check52_import.log
foreach ($stage in @('5_2','0','1','1_1','2','2_1','3','3_1','4','5','5_1')) {
    & $martGodot --path . --script "res://tests/prompt${stage}_smoke.gd" 2>&1 | Tee-Object ".godot/check52_prompt${stage}.log"
}
& $martGodot --headless --path . --fixed-fps 60 --quit-after 7200 2>&1 | Tee-Object .godot/check52_main.log
```

## Prompt 5.1 — Agent 지침 + 실제 구매 Shelf 방문 (구현·자동 검증 완료)

- 사용자 수동 피드백: Prompt 5의 Drunk Customer/Character Carry에는 큰 문제가 없었으나 일반 손님이 실제 상품 앞을 방문하지 않았다. 이번 범위는 그 쇼핑 표현 수정과 Agent 문서 구조 추가다. Lost Child 및 다른 콘텐츠는 추가하지 않았다.
- 새 최상위 지침 `AGENTS.md`와 `.agents/skills/gameplay-development/SKILL.md`, `godot-testing/SKILL.md`, `bug-fix/SKILL.md`를 생성했다. 세 Skill은 YAML name/description을 포함한다. 각각 조작감/시스템 상호작용, 기존 Godot·회귀 절차, 원인 확인·최소 수정·emergent behavior 보존을 담당한다. 이번 구현에서도 세 문서를 읽고 적용했다.
- 실제 원인: `CustomerManager.spawn_customer()`가 모든 구매 목록에 동일한 왼쪽 통로 waypoint를 주었고, `BasicCustomer`는 STORE waypoint가 비면 곧바로 `join_queue()`를 호출했다. 기존 예약/실제 판매는 이미 결제 시 처리했지만, 해당 상품의 Shelf 방문 검증과 쇼핑 행동이 없었다.
- `StockShelf`에 실제 앞면(local +Z) 기준 Shopping Point를 추가했다. 기본 3개, Inspector `shopping_point_count` 2~4, `shopping_front_distance=1.35m`, 가로 위치 -0.95~+0.95m. 현재 마트의 180도 회전 Shelf에서도 앞면은 월드 Z≈4.65가 된다. 표시용 디버그 오브젝트/Release UI는 추가하지 않았다.
- Shelf의 `_shopping_users`는 공간 사용 예약만 담당한다. 실제 상품 예약 `_claims`와 분리한다. 해당 손님의 실제 예약 상품에 가장 가까운 빈 Point를 고르고, 모두 차면 앞 통로의 분산된 대기 위치에서 재시도한다. 정상 쇼핑 후 포인트에서 벗어날 때 반환하며 품절/퇴장/노드 삭제 때도 반환한다.
- 손님 `shopping_types`는 구매 목록에서 중복을 제거한 종류 순서이며, `visited_types`는 완료한 종류다. Can×2+Watermelon×1은 Can 한 번/Watermelon 한 번을 방문한다. 실제 상품 참조와 수량은 그대로 유지한다.
- 상태는 STORE(진입/실제 Shelf 접근) → SHOP → 다음 STORE/SHOP → Queue 접근 → QUEUE → CHECKOUT → EXIT다. 기존 enum 값은 유지하고 SHOP만 뒤에 추가했다. `shopping_time=0.8초`(Inspector 0.5~1.5), Point 근처에서만 시간을 줄이며 Shelf 방향으로 회전하고 몸통을 약간 기울인다. 구매 아이콘과 앞쪽 작은 방향 표시를 사용한다. 상품을 들고 가지 않는다.
- 현 마트 배치용 간단한 waypoint로 진열대 앞 통로와 오른쪽 끝을 돌아 Queue에 진입한다. 좌우 이동 경로 높이(Z)를 구분하며 본격 Navigation/Crowd AI는 없다. Shelf 앞 품절 손님은 앞 통로→왼쪽 측면→출구로 돌아가 진열대 내부를 가로지르지 않는다.
- 이동/SHOP 중에도 기존 `valid_goods()`를 사용한다. 상품 이동/Grab/파손이면 기존 DISAPPOINTED/Exit 및 예약 해제를 실행한다. `finish()`의 원자적 재검증·매출/손실·실물 제거 코드는 변경하지 않았다. Patience는 기존처럼 Queue 진입 후에만 감소한다.
- 변경 코드: `scripts/systems/stock_shelf.gd`, `customer_manager.gd`, `basic_customer.gd`. 신규 검사: `tests/prompt5_1_smoke.gd`. Grab/Throw/Cart/Delivery/Drunk 코드와 기존 테스트는 이번 변경에서 그대로 유지한다. README는 사용자 실행/조작법 변경이 없어 수정하지 않는다.
- 알려진 제한: 현재 마트 좌표에 맞춘 통로이므로 Shelf를 옮길 때 동선도 검토해야 한다. 상품/카트가 막으면 손님은 정체될 수 있으며 복잡한 회피는 없다. 쇼핑 중 카트에 밀려 Point를 벗어나면 복귀할 때까지 쇼핑 시간이 멈춘다. Queue 순서는 실제 도착 순서이며 서로 다른 쇼핑 경로에서 생성 순서와 달라질 수 있다. 카트 접촉 반복 피해는 요청대로 보존한다.
- 수동 확인: Can만 진열→해당 손님이 앞면 Point에서 멈추는지, 2종 구매→두 Shelf 방문, 생성 간격 축소→Point 분산, 이동 중 예약 상품 Grab→품절·공간 예약 해제, 취객/카트/진열/계산 병행을 확인한다. 특정 구매 목록은 기존 `Customers.spawn_customer([&"can", &"watermelon"])` API로 재현할 수 있고 새 디버그 키/UI는 만들지 않았다.
- 다음 후보는 Lost Child다. Character Carry 기반은 유지되며 미아/부모/인계는 아직 구현하지 않았다. 아래 Prompt 0~5 기록은 이전 단계의 이력으로 보존한다.

### 연결 복구 후 확인 — 2026-09-29

- 재개 시 `git status` 및 실제 diff부터 확인했다. Agent 문서 4개, 쇼핑 수정 3개 스크립트, `tests/prompt5_1_smoke.gd`와 UID는 이미 존재했다. 신규 검사 36개 통과 로그도 남아 있어 중복 구현하지 않았다. 미완료 작업은 전체 회귀 검증과 최종 기록이었다.
- 재개 시 tracked 수정은 PROJECT_NOTES.md, project.godot, basic_customer.gd, customer_manager.gd, stock_shelf.gd였고 Agent 문서/새 검사는 untracked였다. 아래 Prompt 5 당시의 Git 상태와 구분한다. 이번 작업에서 commit/reset/clean은 하지 않는다.
- `project.godot`에는 기존 `debug_spawn_drunk` K키 입력의 확장된 직렬화와 빈 줄 변경이 있었다. 재개 전에 존재한 변경을 그대로 보존했으며 새 입력 기능은 추가하지 않았다.
- 이전 `final51_*` 검사에서 일부 입력 검사가 실패했다. `.godot/p51_charge_probe.log`에 우클릭 Charge 도중 `mouse_mode=2, focus=true`에서 `mouse_mode=0, focus=false`로 바뀌고 속도가 거의 0이 된 증거가 있다. 게임의 정상 포커스 해제/Charge 취소를 우회하거나 기존 검사를 약화하지 않고 실제 창을 하나씩 열어 전체를 재검사한다. 이전 실패 로그는 보존한다.
- 재개 검사 로그는 `.godot/resumed51_import.log`, `resumed51_prompt{0,1,1_1,2,2_1,3,3_1,4,5,5_1}.log`, `resumed51_main.log`에 기록한다. `.godot`는 Git 제외이므로 다른 체크아웃에서는 아래 명령으로 재생성한다.

### Prompt 5.1 최종 검증과 다음 세션 시작점

재개 후 게임 코드/기존 테스트를 다시 수정하지 않고, 임포트 → 신규 5.1 → 기존 0~5 → Main 순서로 전체 검사를 완료했다. **363개 통과, 실패 0개. 최종 로그 SCRIPT ERROR/ERROR:/FAIL: 0건.** 이전 실패 기록을 삭제하거나 최종 결과로 덮지 않았다.

| Prompt | 통과 | 실패 |
| --- | ---: | ---: |
| 0 | 22 | 0 |
| 1 | 48 | 0 |
| 1.1 | 40 | 0 |
| 2 | 41 | 0 |
| 2.1 | 28 | 0 |
| 3 | 32 | 0 |
| 3.1 | 29 | 0 |
| 4 | 54 | 0 |
| 5 | 33 | 0 |
| 5.1 | 36 | 0 |

- Godot 4.7.2 프로젝트 임포트 성공. Main은 headless/fixed-fps 60/7,200프레임(시뮬레이션 120초) 동안 배송 도착·출발까지 오류 없이 실행했다. 입력 회귀는 headless가 아닌 실제 창으로 순차 실행했다.
- 신규 검사: Can×2+Watermelon×1이 두 Shelf를 각각 한 번 방문하고 실제 앞면 도착/바라보기/쇼핑 정지를 확인했다. 3회 Scan+Payment로 $60 매출 및 실제 상품 3개 제거를 검증했다. 다중 Point 점유·반환, 실제 상품 가까운 Point 선호, 이동 중 예약 상품 Grab→품절→실제 퇴장도 통과했다.
- 기존 검사: 6명 모두 Queue 도착, 최소 간격 약 0.981m. Cart Bomb은 적재 5개 중 2개 이탈, 상품 타격 3회/차체 타격 1회. 취객은 직접 Carry/카트 Launch로 각각 제거되어 drunks_removed=2, 취객 존재 중 정상 계산 $5 성공. 수치는 한 번의 물리 실행 측정이며 결정적 결과를 보장하지 않는다.
- `.godot/p51_shopping.png`를 실제로 열어 Can Shelf 앞 세 손님의 분산 배치를 확인했다. 자동 스크린샷 확인이며 장시간 사람이 직접 플레이한 손맛 검증을 대체하지 않는다.
- Agent 문서 4개 내용 확인 및 세 Skill의 `quick_validate.py` 검사 모두 통과. `git diff --check` 오류 없음. README는 조작법 변경이 없어 그대로다.

재실행 예시(프로젝트 루트 PowerShell, 입력 검사 중 다른 창 클릭/Alt+Tab 금지):

```powershell
$martGodot = 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
& $martGodot --headless --path . --editor --import --quit 2>&1 | Tee-Object .godot/check51_import.log
foreach ($stage in @('5_1','0','1','1_1','2','2_1','3','3_1','4','5')) {
    & $martGodot --path . --script "res://tests/prompt${stage}_smoke.gd" 2>&1 | Tee-Object ".godot/check51_prompt${stage}.log"
}
& $martGodot --headless --path . --fixed-fps 60 --quit-after 7200 2>&1 | Tee-Object .godot/check51_main.log
```

다음 세션은 이 Prompt를 재구현하지 않는다. 먼저 사용자 수동 테스트 결과를 확인한다: (1) 단일 종류 Shelf 앞 도착, (2) 2종 Shelf 방문, (3) 손님 증가 시 분산, (4) 예약 상품 제거 시 품절, (5) 카트/진열/취객/계산 병행. 고정 waypoint·막힌 통로 정체·Point 수 제한은 남아 있다. **카트 밀착 반복 Damage는 의도적으로 수정하지 않았다.** 그 외 새로 확인된 자동 검사 실패는 없다. 이후 Lost Child 요청이 오면 기존 Character Carry를 재사용할 수 있으나 미아/부모/인계 로직은 아직 구현하지 않았다.

## 다음 세션을 위한 인수인계 — 2026-09-29 (Prompt 5 당시 기록)

**아래 인수인계는 Prompt 5 완료 당시 기준이다. 최신 상태는 위 Prompt 5.1 항목을 먼저 확인한다. 다음 기능 후보는 Lost Child이며 아직 구현하지 않았다.** 이 문서는 현재 구현 사실, 이전 검증 기록, 다음 작업 제안을 구분한다. 아래 과거 단계의 수치는 당시 기록이며 Prompt 5 당시 전체 결과는 **327개 통과**다.

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
1. 최신 우선순위는 AGENTS.md를 따른다: Gameplay feel → Toy-like interaction → 빠른 템포 → 단순 규칙의 예상 밖 상황 → 시스템 상호작용 → 테스트 안정성 → 코드 구조. 실행 오류는 해결하되 현실성 때문에 조작감을 희생하지 않는다.
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
