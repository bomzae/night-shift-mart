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

상품 상세 정보는 항상 화면에 띄우지 않고, **Crosshair로 상품을 바라볼 때만** 이름·가격·무게·음식 회복량을 표시합니다.

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

현재 싱글플레이에서는 마지막 Player가 Downed되면 `DAY FAILED`가 발생하고 Prototype Day Reset이 진행됩니다.

---

# ⌨️ Controls

## Basic

| Input | Action |
| --- | --- |
| `WASD` | Move |
| `Space` | Jump |
| `E` | Interact / SCAN / PAY / Open Weapon Crate |
| `LMB` | Grab / Weapon Swing |
| `RMB Hold → Release` | Charge Throw |
| `Q` | Drop |
| `F` | Use Tool |
| `G` | Eat Food / Feed Downed Teammate |
| `Esc` | Toggle Mouse Capture |

## Debug / Prototype

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

### Planned

- ⏳ Full Round / Day Progression
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
