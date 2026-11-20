# 🛒 NIGHT SHIFT MART

> **야간 마트에서 일하고, 사고를 수습하고, 살아남으세요.**  
> 물리 상호작용을 중심으로 한 1인칭 협동 마트 코미디 게임 프로토타입.

**NIGHT SHIFT MART**는 야간 마트 직원이 되어 배송 상품을 나르고, 진열대를 채우고, 손님을 계산하면서 예상치 못한 사건을 처리하는 **3D 물리 기반 게임**입니다.

평범한 마트 업무로 시작하지만 취객, 도둑, 화재, 관광객 러시, 길 잃은 아이, 그리고 거대한 **KING RAT**까지 등장합니다.

상품, 카트, 소화기, 대걸레, 근접 무기 등 대부분의 물체는 실제 물리 오브젝트로 동작하며, 정해진 하나의 해결법보다 **여러 시스템을 조합하면서 벌어지는 상황 자체**를 핵심 재미로 삼고 있습니다.

---

## 🎮 Game Overview

| 항목 | 내용 |
| --- | --- |
| Engine | Godot 4.7.2 |
| Genre | First-person Physics / Co-op Comedy |
| Current Build | Single-player Prototype |
| Target | 2–4 Player Co-op |
| Store Size | 72 × 36 m |
| Products | 18 types |
| Interaction | Grab · Drop · Throw · Push · Carry · Melee |
| Boss Prototype | KING RAT |

---

## 🌙 Core Gameplay Loop

한 번의 영업은 **22:00부터 다음 날 06:00까지**, 기본 실제 시간 **20분**입니다. 우측 상단에서 Day와 현재 시간을 확인할 수 있습니다.

첫날은 선반 약 40%가 진열된 상태로 시작합니다. 22:00~23:00에는 손님과 배송 업무를 익히고, 이후 취객 → 길 잃은 아이 → 도둑 순서로 사건을 소개합니다. 이전 사건이 남아 있으면 다음 자동 사건은 기다립니다. 04:00~05:30에는 KING RAT이 하루 최대 한 번 자동 등장할 수 있습니다. 사건이 시작되면 화면 상단에 이름과 짧은 행동 안내가 표시됩니다.

둘째 날부터는 더 자유로운 사건 일정이 적용됩니다. 시작 재고는 첫날에만 제공되며, 추가 상품은 배송받아 직접 진열합니다.

우측 상단 Day/Clock 아래에서 **당일 SALES / LOSSES**를 확인할 수 있습니다. 결제나 손실이 발생하면 짧은 금액 변화가 표시됩니다. LOSSES에는 미결제·도난·화재·Boss·파손·회복에 사용한 음식 가치가 포함되며, 세부 내역은 영업 결과 화면에서 확인합니다.

06:00 또는 전원 Downed 시 영업을 마치고 매출·손실·처리한 사건을 결과 화면에서 확인합니다. **E / Enter**로 다음 날을 시작합니다. 다음 날에도 선반의 실제 재고는 유지되고, 바닥 상품과 남은 사건은 정리됩니다. 카트·도구·무기는 제자리로 돌아오며 무기 내구도와 도구 잔량은 유지됩니다.

### 1. 배송을 받는다

트럭으로 도착한 상품을 직접 운반합니다.

상품 하나씩 옮길 수도 있지만, 카트를 이용하면 훨씬 빠릅니다.

### 2. 진열대를 채운다

상품 종류와 진열 위치에 맞춰 매대를 채웁니다.

작은 상품은 2단·3단 선반에 진열되며, 잘못 올려놓은 물건도 강제로 정리되지 않고 그대로 물리 오브젝트로 남습니다.

### 3. 손님을 응대한다

손님은 실제 진열 상품을 가져갑니다.

상품이 사라지면 재고도 줄어들며, 계산대에서 직접 **SCAN → PAY** 과정을 처리해야 합니다.

### 4. 돌발 상황을 해결한다

영업 중 다양한 사건이 발생합니다.

- 🍺 Drunk Customer
- 🧒 Lost Child & Parent
- 💦 Spill Accident
- 🔥 Fire
- 🥷 Thief
- 🚌 Tourist Rush
- 🐀 KING RAT

취객은 여러 통로와 매대 앞을 비틀거리며 돌아다닙니다. 실제로 매대를 건드리면 상품이 흐트러지거나 떨어질 수 있으니, 직접 들거나 카트에 태워 Exit로 데려가세요. 무거운 상품의 물리 저항과 Spill에서 넘어지는 상호작용도 유지됩니다.

### 5. 마트에 있는 모든 것을 활용한다

정답은 하나가 아닙니다.

상품을 던지고, 카트를 들이받고, 소화기로 밀어내고, 무기를 배송받아 싸울 수도 있습니다.

---

# 🧸 Physics Playground

NIGHT SHIFT MART의 핵심은 **물건이 단순 장식이 아니라 실제 Gameplay 도구라는 것**입니다.

## Grab / Throw

대부분의 상품은 직접 들고 던질 수 있습니다.

- **가격이 높을수록** 공격력이 증가합니다.
- **무게가 무거울수록** 투척 속도와 거리가 감소합니다.
- 우클릭을 길게 눌러 Charge Throw가 가능합니다.

가벼운 과자와 무거운 TV는 같은 방식으로 날아가지 않습니다.

---

## 🛒 Shopping Cart

카트는 단순 운반 수단이 아닙니다.

- 상품 적재
- Push / Pull
- 방향 전환
- Player / NPC 물리 상호작용
- Charge Launch
- Loaded Cart 공격
- Cart Bomb

상품을 가득 싣고 KING RAT에게 그대로 들이받는 것도 가능합니다.

적재물은 Inventory가 아니라 실제 `RigidBody`이므로 충돌이 강하면 밖으로 흩어집니다.

---

## 🧯 Tools

### Fire Extinguisher

화재를 진압하면서 상품, NPC, 카트에 물리적인 Push를 가할 수 있습니다.

### Mop

Spill을 청소하면서 동시에 물체를 밀거나 던질 수도 있습니다.

도구 역시 전용 미니게임이 아니라 기존 물리 시스템 안에서 동작합니다.

---

# 🏪 Supermarket

현재 Graybox 마트는 약 **72 × 36m** 규모입니다.

매장은 여러 구역으로 구성되어 있습니다.

- Produce
- Drinks / Dairy
- Pantry
- Snacks
- Household
- Cookware
- Electronics
- Checkout
- Rear Delivery

중앙 통로, 횡단 통로, 후면 서비스 통로가 연결되어 있어 손님 업무와 카트 이동, 전투가 동시에 발생할 수 있도록 설계했습니다.

---

## 📦 Products

현재 18종의 실제 물리 상품을 지원합니다.

| Product | Price | Weight |
| --- | ---: | ---: |
| Can | $5 | 1.0 kg |
| Instant Noodles | $6 | 0.4 kg |
| Chips | $8 | 0.3 kg |
| Bread | $10 | 0.5 kg |
| Milk | $15 | 1.5 kg |
| Cereal | $18 | 0.8 kg |
| Juice | $20 | 1.5 kg |
| Toilet Paper | $22 | 1.8 kg |
| Glass Drink | $25 | 1.2 kg |
| Shampoo | $25 | 1.0 kg |
| Detergent | $30 | 2.5 kg |
| Cooking Oil | $35 | 2.0 kg |
| Rice Bag | $45 | 5.0 kg |
| Watermelon | $50 | 4.0 kg |
| Frying Pan | $120 | 3.0 kg |
| Vacuum Cleaner | $250 | 6.0 kg |
| Microwave | $300 | 7.0 kg |
| TV | $800 | 10.0 kg |

상품을 **Crosshair로 바라보거나 음식을 들었을 때** 이름·가격·무게·회복량과 현재 가능한 행동을 표시합니다.

---

# 👥 Customers & Events

## Regular Customers

손님은 진열대를 직접 방문하고 실제 상품을 가져갑니다.

이후 계산대에 줄을 서며 Player가 SCAN과 PAY를 처리합니다.

NPC는 카트, 바닥 상품, 다른 이벤트 때문에 경로가 막힐 수 있으며, 장시간 진행하지 못하면 단계적으로 경로와 목표를 다시 계산합니다.

---

## 🚌 Tourist Rush

관광버스가 도착하면 여러 손님이 한꺼번에 마트로 들어옵니다.

평소에는 여유 있던:

- 재고
- 진열
- 계산대
- 이동 통로

가 동시에 압박받게 됩니다.

---

## 🥷 Thief

도둑은 실제 진열 상품을 훔쳐 출구로 달아납니다.

가까이 접근해 붙잡으면 상품을 회수할 수 있으며, 놓치면 상품 가격이 손실로 기록됩니다.

---

## 🔥 Fire

일부 손님은 상품을 가져간 뒤 화재를 발생시킬 수 있습니다.

불은 주변 가연성 상품으로 제한적으로 번지며 상품이 완전히 타면 실제 손실로 기록됩니다.

소화기를 가져와 직접 진압해야 합니다.

---

# 🐀 KING RAT

KING RAT은 현재 전투 시스템을 검증하기 위한 첫 번째 Boss Prototype입니다.

평상시에는 Player를 무조건 공격하지 않고 마트를 돌아다니며 상품을 먹습니다.

Player가 공격하거나 지속적으로 방해하면 Aggro 상태로 전환됩니다.

### Combat Flow

`Roam → Aggro → Approach → Telegraph → Charge → Recovery`

KING RAT은 공격 전 명확한 Telegraph를 보여주며, Charge가 시작되면 방향이 고정되기 때문에 옆으로 피할 수 있습니다.

Player 공격에 따라 상황도 달라집니다.

- **Approach 중 Hit** → 밀려난 뒤 공격 의도를 유지하고 다시 접근
- **Telegraph 중 Hit** → 같은 공격 준비를 유지
- **Charge 중 Hit** → 현재 돌진 중단 후 전투 판단 재시작

일반 몸 접촉도 Player에게 피해를 주지만, Charge는 더 큰 피해와 Knockdown을 발생시킵니다.

---

# 🔨 Weapons

무기는 Inventory에 들어가는 장비가 아니라 **실제 World Physics Object**입니다.

후면 배송 구역으로 Weapon Crate를 주문하고 직접 가져와 사용합니다.

| Weapon | Damage | Range | Cooldown | Durability | Role |
| --- | ---: | ---: | ---: | ---: | --- |
| Baseball Bat | 22 | 2.2m | 0.65s | 14 | 빠르고 안정적인 기본 무기 |
| Sledgehammer | 48 | 2.0m | 1.35s | 10 | 느리지만 강한 Heavy Hit |
| Heavy Broom | 12 | 2.8m | 0.55s | 18 | 긴 사거리와 강한 Push |

Weapon도:

- Grab
- Drop
- Throw
- Cart 적재

가 가능합니다.

무기만 사용하는 것이 아니라 상품 투척과 Cart Bomb을 섞어 싸우는 것이 현재 전투 방향입니다.

---

# ❤️ Player Health

Player 기본 HP는 **100**입니다.

음식은 실제 상품이면서 회복 아이템 역할도 합니다.

| Food | Self Heal | Revive Heal |
| --- | ---: | ---: |
| Bread | +15 | +30 |
| Milk | +20 | +40 |
| Watermelon | +30 | +60 |

Downed 상태에서는 혼자 일어날 수 없습니다.

향후 멀티플레이에서는 살아 있는 동료가 음식을 먹여 부활시킬 수 있도록 구조화되어 있습니다.

현재 싱글플레이에서는 마지막 Player가 Downed되면 `DAY FAILED` 후 결과 화면으로 이동합니다. E / Enter로 다음 날을 시작하면 HP와 위치가 복구됩니다.

---

# ⌨️ Controls

## Gameplay

시선 대상과 들고 있는 물건에 맞춰 조준점 아래에 핵심 행동을 최대 두 개 표시합니다. 상품을 보면 이름·가격·무게·회복량도 확인할 수 있습니다.

| Input | Action |
| --- | --- |
| `WASD` | Move |
| `Space` | Jump |
| `E` | 상황별 상호작용: SCAN / PAY / 무기 상자 열기 / 음식으로 쓰러진 동료 회복 |
| `LMB` | Grab / Weapon Swing |
| `RMB Hold → Release` | Charge Throw |
| `Q` | Drop |
| `F` | 소화기 분사 / 들고 있는 음식 먹기(HP 부족 시) |
| `Esc` | Toggle Mouse Capture |

## Debug / Prototype

아래 키는 개발용이며 기본 플레이에서 외울 필요가 없습니다. 기존 `G` 음식 사용은 호환 입력으로 남아 있지만, 기본 안내는 자기 회복 `F` / 동료 회복 `E`입니다.

| Input | Action |
| --- | --- |
| `I` | Auto Stock |
| `U` | Toggle Customer Spawn |
| `R` | Spawn KING RAT |
| `N` | Order Weapon |
| `B` | Tourist Bus |
| `T` | Thief |
| `K` | Drunk Customer |
| `L` | Lost Child |
| `O` | Accident Customer |
| `P` | Dangerous / Fire Customer |
| `H` | Damage Player |
| `J` | 영업 시간 +1시간 |

---

# 🚀 Getting Started

## Requirements

- **Godot 4.7.2**
- Windows recommended for the current development environment

Clone the repository:

```bash
git clone https://github.com/bomzae/night-shift-mart.git
cd night-shift-mart
git switch develop
```

Open `project.godot` with Godot 4.7.2.

Run the project with:

```text
F5
```

Main scene:

```text
scenes/main/main.tscn
```

Mart scene:

```text
scenes/mart/mart_graybox.tscn
```

---

# ⚡ Quick Prototype Setup

게임 시스템을 빠르게 확인하려면:

```text
F5
→ I
→ U OFF
→ R
```

- `I` — 모든 정상 Shelf에 상품 보충
- `U OFF` — 자동 Customer 생성 정지
- `R` — KING RAT 생성

Weapon까지 테스트하려면:

```text
N
→ Rear Delivery Area
→ Weapon Crate에 E
→ Weapon Grab
```

---

# 🧪 Testing

프로젝트에는 Gameplay regression을 위한 자동 테스트가 포함되어 있습니다.

주요 검증 영역:

- Player movement / interaction
- Product physics
- Cart
- Stocking
- Customer / Checkout
- NPC recovery
- Tourist Rush
- Fire / Spill
- Thief
- Player HP / Revive
- KING RAT combat
- Weapon combat
- Delivery
- HUD

Godot 실행 및 회귀 테스트에 대한 세부 정보는 다음 문서를 참고하세요.

```text
PROJECT_NOTES.md
AGENTS.md
.agents/skills/godot-testing/SKILL.md
```

---

# 🧭 Development Status

현재는 **Gameplay Prototype** 단계입니다.

### Implemented

- ✅ First-person interaction
- ✅ Physical Grab / Throw
- ✅ Shopping Cart
- ✅ Delivery
- ✅ Multi-tier Stocking
- ✅ Customer Shopping / Checkout
- ✅ Customer Events
- ✅ Fire / Spill
- ✅ Thief
- ✅ Tourist Rush
- ✅ Player HP / Downed / Food
- ✅ KING RAT
- ✅ Melee Weapons
- ✅ NPC stuck recovery
- ✅ Gameplay QA workflow
- ✅ 22:00–06:00 Shift / Day Result / Next Day

### Planned

- ⏳ Shift pacing / Result UX refinement
- ⏳ Settlement / Economy
- ⏳ Additional Monsters / Bosses
- ⏳ Multiplayer 2–4 Players
- ⏳ Audio / VFX / Final Combat Feedback
- ⏳ Final Art & Level Polish

---

자세한 구현 기록과 테스트 결과는 [`PROJECT_NOTES.md`](PROJECT_NOTES.md)를 참고하세요.

---

# 🛠 Tech

- **Godot 4.7.2**
- **GDScript**
- RigidBody-based physics interactions
- Data-driven Product / Weapon definitions
- Automated gameplay regression tests
- Agent-assisted implementation & gameplay QA
