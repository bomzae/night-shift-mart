# NIGHT SHIFT MART

Godot 4.7.2용 3D 협동 마트 게임의 **Prompt 7.3 / First-person Backward Fall**.
배송 상품을 운반·진열하고 일반 손님의 구매 목록을 스캔·결제합니다.

먼저 [PROJECT_NOTES.md](PROJECT_NOTES.md)를 읽고 개발 범위를 확인하세요.

## 실행
Godot 4.x에서 `project.godot`를 Import한 뒤 **F5**로 실행합니다.
진입 씬은 `scenes/main/main.tscn`이며 마트 Graybox를 자동으로 불러옵니다.
마트 씬은 `scenes/mart/mart_graybox.tscn`입니다. 기존 테스트 룸은
`scenes/test/prototype_test_room.tscn`을 열고 **F6**로 실행합니다.
Main의 `start_in_prototype` 또는 실행 인수 `-- --prototype`으로도 기존 룸에 들어갈 수 있습니다.

이 PC의 ZIP Godot 실행 경로는 아래와 같습니다. 프로젝트 루트의 PowerShell에서 실행합니다.
`D:\Godot_v4.7.2-stable_win64.exe` 자체는 폴더이므로 내부 실행 파일을 지정합니다.

```powershell
& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --path . --editor
```

| Action | 기본 입력 | 상태 |
| --- | --- | --- |
| move_forward / move_backward | W / S | 이동 |
| move_left / move_right | A / D | 이동 |
| jump | Space | 점프 |
| interact | E | 계산대 뒤에서 바라보는 SCAN / PAY 버튼 사용 |
| grab | 마우스 왼쪽 | 상품·카트 손잡이·취객 잡기 / 놓기 |
| throw | 마우스 오른쪽 | 누르는 동안 충전 → 떼면 상품 투척 또는 카트 발사 |
| toggle_mouse_capture | Esc | 마우스 잠금 해제/복귀 |
| debug_spawn_drunk | K | 마트 입구에 테스트 취객 생성(최대 2명) |
| debug_spawn_lost_child | L | 개발용 미아·부모 쌍 생성(최대 2쌍) |
| debug_spawn_accident | O | 개발용 사고 손님 생성(최대 2명, 일반 손님 전체 인원 제한도 적용) |

## 사고 손님 / 미끄러운 바닥 / Mop

먼저 상품을 진열한 뒤 **O**를 누릅니다. 사고 손님은 첫 Shelf에서 상품을 챙긴 직후 한 번 물을 쏟고,
잠깐 당황한 표정 뒤 기존 쇼핑·계산을 계속합니다. 재고가 없어 쇼핑하지 못하면 사고 없이 퇴장합니다.
입구가 막혔거나 손님 수가 최대이면 생성을 건너뛰므로 공간을 비우고 다시 누릅니다.

파란 원형 물웅덩이는 Player·손님·취객·카트·바닥 상품의 제동/마찰을 낮춥니다. 시간이 지나도 사라지지 않습니다.
캐릭터가 중앙부를 충분한 속도로 밟으면 넘어집니다. Player 시점은 약 1.1m 낮아지고 뒤로 75° 젖혀져 위쪽을 바라보며,
약 1.4초 동안 이동·점프·상호작용을 쉬지만 마우스로 주변을 볼 수 있습니다.
들고 있던 상품·캐릭터·카트는 놓고 Charge는 취소됩니다. 일어난 뒤 1.3초 동안 재넘어짐을 막습니다.
가장자리 접촉이나 정지 상태만으로 넘어지지 않습니다. 카트·상품에는 넘어짐 상태가 없습니다.
**Mop은 뒤편 Backroom 오른쪽, 좌표 (7.5, 0.85, -1.5)**에 있습니다. 좌클릭으로 집고 물웅덩이를 내려다보며
Mop의 흰색 머리를 바닥에 대고 좌우로 문지릅니다. 실제 머리가 움직일 때만 파란 영역이 줄어들고 없어집니다.
줄어드는 영역의 중앙을 따라 닦아야 하며 가만히 두거나 공중에서 흔드는 것으로는 청소되지 않습니다.
화면 오른쪽 상단 SPILLS / CLEANED로 생성·청소 횟수를 확인합니다.

Mop도 좌클릭 Drop / 우클릭 Charge Throw가 가능하고 상품·NPC·카트와 물리적으로 충돌합니다.
판매 상품이나 별도 무기는 아니며, 멀리 던지면 그곳에 남습니다.
신규 검사: 같은 Godot 실행 파일에 `--path . --script res://tests/prompt7_smoke.gd`를 전달합니다.
넘어짐 검사: `--path . --fixed-fps 60 --script res://tests/prompt7_1_smoke.gd`.
1인칭 누운 자세·시점·복구 검사: `--path . --fixed-fps 60 --script res://tests/prompt7_2_smoke.gd`.
Backward Fall 방향·Look 보존 검사: `--path . --fixed-fps 60 --script res://tests/prompt7_3_smoke.gd`.

## 미아와 부모 찾기

F5 → **L**로 매장 안에 미아와 부모를 생성합니다. 생성 위치가 막혀 있으면 비우고 다시 누릅니다.
아이와 부모의 **같은 색·도형(노란 원 / 청록 마름모)**을 찾습니다. 부모는 쇼핑이나 계산 없이 기다립니다.
미아를 좌클릭으로 들고 부모에게 접근합니다. 맞는 부모 약 1.8m 이내에서 체크 표시가 보이면
**다시 좌클릭해 내려놓습니다**. 하트 표시와 FOUND 증가 후 둘이 함께 출구로 이동합니다.

잘못된 부모나 일반 위치에 놓아도 아이가 사라지거나 금전 손실이 발생하지 않습니다. 시간 제한도 없습니다.
미아 운반 속도는 일반 이동의 98%(취객 85%)이며 우클릭으로 던질 수 없습니다.
카트에 내려놓아 운반할 수 있지만 좌석 고정은 없습니다. 부모 앞에서 다시 들어 Drop하면 인계합니다.
출구 제거 구역은 취객 전용이므로 미아를 밖으로 보내는 것은 해결이 아닙니다.
재회한 아이는 부모의 뒤·옆을 따라갑니다. 퇴장 가족은 서로 및 일반 손님과 길을 막지 않도록 통과하며,
부모가 출구에 도착하면 아이도 함께 정리됩니다. 카트/상품/Player 등 실제 장애물로 부모의 통로를 완전히 막으면 여전히 정체될 수 있습니다.

신규 검사: 같은 Godot 실행 파일에 `--path . --script res://tests/prompt6_smoke.gd`를 전달합니다.
퇴장 교차 검사: `--path . --script res://tests/prompt6_1_smoke.gd`.

## 취객 테스트

F5로 마트를 실행하고 **K**를 누릅니다. 입구가 막히면 생성을 건너뛰므로 공간을 비우고 다시 누릅니다.
보라색 취객은 계산하지 않고 비틀거리며 상품을 밀어냅니다. 가까이서 바라보고 **좌클릭**하면 들고,
다시 좌클릭하면 놓습니다. 운반 중 이동 속도는 85%이며 **우클릭으로 취객을 던질 수 없습니다**.

취객을 전면 **ENTRANCE** 문 밖 초록 **EXIT** 구역으로 운반하면 REMOVED가 증가합니다.
들고 진입하거나, 카트 안에 내려놓고 밀기/Charge Launch로 보내도 같은 제거 판정을 사용합니다.
카트에는 좌석 고정이 없어 큰 충돌 시 이탈할 수 있습니다. Drop 후 바닥에 서면 보행을 재개합니다.

화면의 BROKEN은 취객의 강한 충돌로 파손된 상품 가격 합계입니다. 일반 접촉이 모든 상품을 파괴하지는 않습니다.
생성은 Mart의 Drunks Inspector에서 끌 수 있습니다. 취객 처리 중에도 배송·진열·일반 손님 계산은 계속됩니다.
Character Throw, ragdoll, 플레이어 피해와 멀티플레이는 구현하지 않았습니다.

신규 검사: 같은 Godot 실행 파일에 `--path . --script res://tests/prompt5_smoke.gd`를 전달합니다.

마우스로 시점을 회전합니다. 창이 포커스를 잃으면 Esc로 조작을 재개합니다.
키 바인딩은 Project Settings → Input Map에서 변경합니다.

물체에 2.8m 이내로 접근해 아래를 보고 조준합니다. Crosshair는 잡을 수 있으면 초록색,
들고 있으면 주황색입니다. 한 번에 하나만 들 수 있습니다.

짧게 눌렀다 떼면 약한 Toss, 약 0.6초는 절반 충전, 1.2초 이상은 최대 충전입니다.
Crosshair 아래 작은 주황색 게이지로 충전량을 확인합니다. 최대 충전에서도 떼기 전에는 던지지 않습니다.
Drop·강제 놓기·Esc·포커스 상실 시 충전이 취소되고 게이지가 초기화됩니다.

| 물체 | 색상 | price | weight |
| --- | --- | --- | --- |
| A | 하늘색 | 5 | 1 |
| B | 초록색 | 5 | 8 |
| C | 노란색 | 50 | 4 |
| D | 분홍색 | 500 | 1 |
| E | 보라색 | 500 | 8 |

빨간 **DAMAGE** 타깃은 HP와 마지막 피해를, 보라색 **KNOCKBACK** 타깃은 충격량과 밀림도 보여줍니다.
타깃 가까이(약 3~4m) 접근해 몸통을 조준하세요. 바닥/벽을 먼저 맞힌 투척은 피해를 주지 않습니다.
최대 충전에서 가격 5는 피해 3.3, 가격 500은 피해 33입니다. 같은 충전량에서 무거운 물체는
느리고 짧게 날아가지만 더 큰 넉백을 줍니다. 초기화하려면 F8로 종료 후 F5로 다시 실행합니다.

## 카트 테스트
오른쪽 카트의 **주황색 손잡이**를 조준해 좌클릭하고 WASD와 시점으로 밀고 당깁니다.
바구니의 상품을 조준하면 상품만 잡습니다. 손잡이를 잡은 상태의 우클릭 충전/해제는 카트를 발사합니다.

1. 빈 카트의 밀기·당기기·방향 전환을 확인합니다.
2. 상품을 집어 열린 바구니 위에서 Drop하고 총 적재 kg와 조작감 변화를 확인합니다.
3. 옆에서 점프해 바구니 바닥에 올라섭니다. 별도 탑승 모드는 없습니다.
4. Tap/Full 발사와 타깃 충돌을 비교합니다.
5. 여러 상품을 싣고 Full Charge하여 카트 충돌·상품 이탈·개별 상품 피해를 확인합니다.
6. 왼쪽 경사로의 느린 구르기와 고속 사고를 비교합니다. 뒤집히면 손잡이 쪽에서 다시 잡아 물리적으로 세웁니다.

북쪽 우측 개구부는 긴 카트 통로로 이어집니다. 카트 타깃은 기존 타깃과 같은 HP/넉백 구조를 사용합니다.
상품은 고정되지 않습니다. 발사 시 적재물에도 한 번의 임펄스를 전달하고, 강한 충돌 시 상승 충격을 더해
실제 물리적으로 튀어나오게 합니다. 타깃을 자동으로 맞히거나 상품을 순간 이동시키지 않습니다.

## 구조
- `scenes/main/`: 프로젝트 진입 씬.
- `scenes/test/`: 바닥·벽·조명·플레이어 시작점.
- `scenes/player/`: 플레이어 충돌체와 카메라.
- `scripts/player/`: Action 기반 로컬 이동/시점 제어.
- `scripts/interaction/`: 입력/선택, 공통 물리 오브젝트, 테스트 타깃.
- `scenes/interactables/`: 모든 테스트 물체가 공유하는 물리 씬.
- `tests/`: Prompt 0~6 물리·마트 업무·손님·취객·미아 회귀 검사.

이동/충돌은 Godot의 [CharacterBody3D](https://docs.godotengine.org/en/4.0/classes/class_characterbody3d.html)를 사용합니다.
Hold 위치의 충돌 여유는 [PhysicsDirectSpaceState3D.cast_motion](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html#class-physicsdirectspacestate3d-method-cast-motion)으로 검사합니다.
주요 조절 값은 Player 씬의 Interaction 노드에 모여 있습니다. 자세한 기본값과 제한은 PROJECT_NOTES.md를 참고하세요.
카트는 `scenes/interactables/shopping_cart.tscn`, 확장 통로/경사로는 `scenes/test/cart_test_zone.tscn`입니다.
입고·진열·일반 손님·계산은 마트 씬에서 검증합니다. 취객·미아 외 특수 손님·Cart Rocket·멀티플레이는 아직 구현하지 않았습니다.

## 일반 손님과 계산

1. 상품을 진열합니다. 기본 6~10초마다 손님이 입장하며 최대 6명입니다. 손님은 구매 Shelf 앞에서 쇼핑한 뒤 예약 상품을 챙깁니다. 이때 실물과 Stock Count가 줄고 머리 위 해당 상품 아이콘에 초록 체크가 표시됩니다.
2. 매장 앞 우측 계산대 **뒤쪽**으로 들어갑니다. 계산 위치에 도착한 손님의 구매 아이콘이 표시됩니다.
3. 파란 **SCAN**을 보고 **E**를 한 번씩 누릅니다(0.5초 간격). 상품 한 개씩 체크됩니다.
4. 모두 처리하면 초록색 **PAY** 버튼을 보고 **E**로 결제합니다. 이미 챙긴 상품의 가격만 Sales에 더하며 Shelf 상품을 다시 제거하지 않습니다.
5. 자리를 떠나거나 기존 Grab/Throw/Cart 작업을 해도 조작이 잠기지 않습니다. 돌아오면 해당 손님의 스캔 진행을 이어갑니다.

Queue 진입부터 25초가 지나면 손님은 미결제로 떠납니다. 표정은 :) → :| → :! → [!]로 변하고,
이미 챙긴 상품 가격만 Unpaid Loss로 한 번 기록하며 상품은 Shelf로 돌아오지 않습니다.
픽업 전 품절은 X / :( 표시 후 퇴장하며 손실이 없습니다. 여러 Shelf 중 일부에서만 챙긴 뒤 품절되면 챙긴 부분만 미결제 손실입니다.
SHOP 완료 전 예약 상품도 플레이어가 자유롭게 집을 수 있으며, 그러면 손님은 품절로 처리됩니다.
Customers Inspector에서 생성 간격·최대 수·Patience·Queue 간격을 조절합니다.
일반 손님은 Grab/피해/사망 대상이 아니며 카트에 닿으면 제한된 물리 반응만 합니다.
통로를 완전히 막으면 고정 waypoint 손님이 막힐 수 있습니다. 취객·미아 외 특수 손님과 Scanner 장난 반응은 아직 없습니다.

```powershell
& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --path . --script res://tests/prompt4_smoke.gd
& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --path . --script res://tests/prompt5_2_smoke.gd
```

## 입고와 진열

1. F5로 시작하고 5초 기다립니다. 오른쪽 트럭 옆 팔레트에 3종 상품이 각 2개 배송됩니다.
2. 상품을 직접 들거나 카트에 내려놓습니다. 기존 좌클릭 Grab/Drop, 우클릭 Charge Throw를 그대로 사용합니다.
3. 전방의 폭 5m 후면문을 직진해 매장으로 들어갑니다. 카트 시작 위치에서 주요 통로까지 약 6m이며 필수 코너는 없습니다.
4. 캔은 파란 Shelf(8개), 수박은 초록 Shelf(5개), 가전은 주황 Shelf(3개)에 놓습니다.
5. 상품이 안정적으로 멈추면 수량이 증가합니다. 다시 집으면 감소합니다. 잘못된 상품과 초과 적재도 물리적으로 허용합니다.
6. 트럭은 60초 체류 후 떠나고 팔레트에 남은 이번 배송분은 회수합니다. 이미 하역하거나 손에 든 상품은 유지됩니다. 다음 도착은 첫 도착으로부터 120초 뒤입니다.

마트의 Delivery 노드에서 배송 시간·상품 씬·최대 활성 상품 수(기본 36)를 조절합니다.
남은 물체가 생성 위치를 막으면 해당 상품 생성을 건너뜁니다. 금전 손실 계산은 없습니다.
빠른 가속·좌우 조향, 진열대 끝 90도 회전, 과적, 상품 투척 운반은 수동으로 추가 확인하세요.
빈 카트와 적재 카트 모두 걷는 속도에 빠르게 도달하며, 적재 시 가속·조향·제동 패널티는 완만해졌습니다.
Tap/Full Launch와 Cart Bomb은 유지했습니다. 카트 밀착 반복 피해는 의도적으로 수정하지 않았습니다.

```powershell
& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --path . --script res://tests/prompt3_smoke.gd
& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --path . --script res://tests/prompt3_1_smoke.gd
```

## 검증
기록된 Godot `4.7.2.stable.official.ed1daf0bf`로 실행합니다.
Prompt 1 검사는 실제 창에서 Action 입력, Carry, 실제 투척/타깃 접촉, 피해와 넉백을 검사합니다.
최종 결과: Prompt 0 22개 / Prompt 1 48개 / Prompt 1.1 40개 / Prompt 2 41개 / Prompt 2.1 28개 / Prompt 3 32개 / Prompt 3.1 29개 / Prompt 4 54개 / Prompt 5 33개 통과(총 327개).
프로젝트 임포트·기본 Main 120초 시뮬레이션(배송 도착/출발 포함)·아홉 검사 최종 로그 오류 0건입니다. Prompt 4에서는 실제 E 스캔/결제, 매출 $55 및 미결제 손실 $5, 상품 제거, 품절 취소, 6명 대기열(최소 간격 약 1.25m)을 확인했습니다.
새 카트는 빈/16kg 적재 모두 0.3초에 약 5m/s에 도달했고, 90도 회전 후 0.5초의 방향 오차는 약 5~6도였습니다.
Prompt 3에서는 9kg 적재 카트의 직선 후면문 동선, 종류별 진열/재Grab/Throw, 잘못된 진열,
초과 진열, 도착/출발 반복과 하역·손에 든 상품의 보존을 검사합니다.
같은 높이의 수평 투척에서 1kg은 Tap 2.99m / Half 7.91m / Full 12.82m,
8kg은 Tap 1.09m / Full 4.66m로 확인했습니다. 접촉과 입력 시간에 따라 수치는 달라집니다.
카트 초기 속도는 빈 상태 Tap 4.15 / Full 17.90m/s, 16kg 적재 Tap 2.57 / Full 11.17m/s였습니다.
Cart Bomb은 5개 적재에서 차체 1회·개별 상품 1회 피해와 2개 이탈을 확인했습니다. 개별 상품 피해 검사는 고정 수신 타깃을 사용하고, 차체 넉백은 별도 검사합니다. 적재 카트 가속/제동 검사는 동일 코드 재실행에서 통과한 변동 사례가 있습니다.
Prompt 5에서는 직접 운반/카트 발사 제거 각 1명, 파손 금액 $500 단일 기록, 취객과 일반 계산 병행을 확인했습니다.
실제 키보드/마우스 조작감과 Alt+Tab 동작은 PROJECT_NOTES.md의 수동 검증 순서로 확인하세요.

```powershell
& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --path . --script res://tests/prompt0_smoke.gd
& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --path . --script res://tests/prompt1_smoke.gd
& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --path . --script res://tests/prompt1_1_smoke.gd
& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --path . --script res://tests/prompt2_smoke.gd
```

각 테스트는 수십 초 동안 자동 입력을 적용하므로 실행 중 입력하거나 창을 전환하지 않습니다.
헤드리스에서는 마우스 잠금을 지원하지 않으므로 이 검사는 창 모드에서 실행합니다.

## Prompt 2.1 조작감 개선

조작키는 그대로입니다. 카트를 잡으면 이동 입력이 카트 제어에 직접 전달되며,
현재 잡은 카트와 플레이어 사이 충돌만 일시 제외합니다. 놓거나 발사하면 복원됩니다.
빈 카트와 16kg 적재 카트는 모두 즉시 가속을 시작하고, 적재 시 가속·조향 상한이 낮아집니다.
잡지 않은 상품과 카트는 WASD로 몸을 부딪혀 밀 수 있습니다.

추가 검사:
```powershell
& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --path . --script res://tests/prompt2_1_smoke.gd
```

수동 확인: 빈 카트 전후진·회전 → B/E 적재 후 반복 → 벽까지 밀고 놓기 →
바닥의 A/B를 몸으로 밀어 비교 → 빈 카트 몸 밀기 → Full Charge/Cart Bomb → 점프 탑승.
자동 검사만으로 떨림이나 조향 만족도를 확정하지 않으며, 급격한 회전·끼임은 직접 확인해야 합니다.
